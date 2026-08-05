# `k` — Kubernetes toolkit

A single `k` dispatcher for the local k3s cluster, modelled on the `ai` toolkit:
a **closed set of subcommands**, each with its own `-h/--help` and an explicit
flag list, plus `k x …` for **raw kubectl**. There is no implicit passthrough —
so completion is entirely ours and `k <sub> --help` always shows *our* help, not
kubectl's.

```
k <helper> [args…]   # smart helper   (pods, log, sh, desc, ns, pf)
k x <args…>          # raw kubectl    (get, apply, scale, rollout, … + full native completion)
```

Why a closed set instead of "anything falls through to kubectl": kubectl is an
*open* surface (dozens of verbs × hundreds of resources × hundreds of flags), so
implicit passthrough means its `--help` and completion leak into `k`, and near
misses like `k logs` vs the helper `k log` collide. Keeping the helpers closed
and routing everything else through the explicit `k x` escape hatch makes both
sides predictable.

## KUBECONFIG

`k` resolves the kubeconfig once (via `_k_kubeconfig`) and exports it for the
dispatched helper / kubectl call:

- `$K_KUBECONFIG` if set (override per-shell or per-project), otherwise
- the hardcoded default `~/work/rf/local-config/k3s/config`.

Nothing is exported globally — it lives in `k`'s function scope only.

## Pod matching

`log`, `sh`, `desc`, `pf` take a **substring** of the pod name, resolved by
`_k_resolve_pod` across all namespaces (or within `-n NS`):

- one match  → used directly;
- no match   → error;
- many matches → the candidates are listed (name + namespace) and the command
  aborts, so you can narrow the substring or add `-n`.

## Helpers

| Command | Purpose |
|---|---|
| `k pods [NS]` | Pod overview; defaults to all namespaces. Non-Running red, Running-but-not-ready yellow. Summary line at the bottom. |
| `k log <sub> [-f] [-g PAT] [-t N] [-p] [-c C] [-n NS]` | Tail a pod's logs. `-f` follow, `-g` grep, `-t` tail lines (default 100), `-p` previous instance (crashes), `-c` container. All containers with `--prefix` by default. |
| `k sh <sub> [CMD…] [-c C] [-n NS]` | Exec into a pod. No CMD → interactive shell (bash if present, else sh). |
| `k desc <sub> [-n NS]` | `describe pod` + its recent events — the "why won't it come up?" view. |
| `k ns [NS]` | No arg: list namespaces, current marked. With NS: set the default namespace on the current context. |
| `k pf <sub> <PORT> [-n NS]` | Port-forward. `PORT` is `LOCAL:REMOTE` or a single port for both. |
| `k x <args…>` | Raw kubectl with the kubeconfig applied — the escape hatch for everything not covered above. |

Each helper takes `-h/--help` for its own options. Namespace is
`-n/--namespace` everywhere (matches kubectl). In `k log`, tail count is
`-t/--tail` (not `-n`, to avoid colliding with namespace). Any unknown first
token errors with a hint to use `k x …`.

## Raw kubectl — `k x`

```fish
k x get pods -A
k x apply -f manifest.yaml
k x rollout restart deploy/clickhouse -n clickhouse
k x scale deploy/kafka -n kafka --replicas=2
k x logs <full-pod-name> --previous
k x describe deploy/foo
k x exec -it <pod> -- sh
```

`k x` gets **full native kubectl completion** — verbs, resource types, resource
names, namespaces, pods, plus file paths after `-f/--filename/-k/--kustomize`.

## Completion

All completion is defined by us (no `-w kubectl` inheritance):

- **First token** — the closed command set (`pods/log/sh/desc/ns/pf/x/help`).
  Nothing else appears, so no kubectl noise and no `log`/`logs` ambiguity.
- **Helper args** — `k log/sh/desc/pf <TAB>` completes pod names by substring
  (`_k_complete_pods`); `k pods/ns <TAB>` and any `-n` completes namespaces
  (`_k_complete_ns`). Gated by `__k_using` (the *first* token must be the
  helper) so a stray word later in the line can't trigger them.
- **`k x` args** — bridged to kubectl's own engine via `__k_x_complete`, which
  calls `kubectl __complete …` (with `KUBECONFIG` applied), strips the trailing
  `:<directive>` line, and hands the rest to fish. `__k_x_wants_file` re-enables
  path completion after file-taking flags.

## Files

- Dispatcher + help: `fish/.config/fish/functions/k.fish` (`k`, `_k_help`)
- Helpers: `fish/.config/fish/functions/_k_{pods,log,sh,desc,ns,pf}.fish`
- Internals: `_k_kubeconfig.fish`, `_k_resolve_pod.fish`,
  `_k_complete_pods.fish`, `_k_complete_ns.fish`
- Completions + bridge: `fish/.config/fish/completions/k.fish`
  (`__k_subcommand`, `__k_using`, `__k_x_complete`, `__k_x_wants_file`)

## Notes / gotchas

- After editing these files, reload the shell (`exec fish`) — fish caches
  loaded completions per session; `stow --restow` relinks files but does not
  reload them.
- No `fzf` dependency: matching is substring-based so it works everywhere.
- `k ns` writes the namespace into the kubeconfig file (`set-context`), so the
  choice persists across shells using the same config.
- Helpers are internal `_k_*` functions invoked only through `k`; they inherit
  `KUBECONFIG` from the dispatcher. The completion helpers set it themselves
  because completions run them outside `k`.
