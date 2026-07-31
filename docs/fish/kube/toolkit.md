# `k` — Kubernetes toolkit

A single `k` dispatcher for the local k3s cluster, in the same shape as the `ai`
toolkit: short-verb **smart helpers** for the everyday cases, and **transparent
kubectl passthrough** for everything else. The point is to stop typing the long
`KUBECONFIG=…` prefix and stop typing full pod names with random hash suffixes.

```
k <helper> [args…]   # smart helper   (pods, log, sh, desc, ns, pf)
k <anything else>    # raw kubectl    (get, apply, logs, describe, exec, …)
```

The helpers live on short verbs (`log`, `desc`, `sh`) so they never shadow
kubectl's real verbs (`logs`, `describe`, `exec`) — raw kubectl is always one
keystroke away under its own name.

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

Tab-completion offers live pod names (namespace shown as the description),
alongside kubectl's own verbs at the first token.

## Helpers

| Command | Purpose |
|---|---|
| `k pods [NS]` | Pod overview; defaults to all namespaces. Non-Running red, Running-but-not-ready yellow. Summary line at the bottom. |
| `k log <sub> [-f] [-g PAT] [-t N] [-p] [-c C] [-n NS]` | Tail a pod's logs. `-f` follow, `-g` grep, `-t` tail lines (default 100), `-p` previous instance (crashes), `-c` container. All containers with `--prefix` by default. |
| `k sh <sub> [CMD…] [-c C] [-n NS]` | Exec into a pod. No CMD → interactive shell (bash if present, else sh). |
| `k desc <sub> [-n NS]` | `describe pod` + its recent events — the "why won't it come up?" view. |
| `k ns [NS]` | No arg: list namespaces, current marked. With NS: set the default namespace on the current context. |
| `k pf <sub> <PORT> [-n NS]` | Port-forward. `PORT` is `LOCAL:REMOTE` or a single port for both. |

Each helper takes `-h/--help` for its own options. Namespace is
`-n/--namespace` everywhere (matches kubectl). In `k log`, tail count is
`-t/--tail` (not `-n`, to avoid colliding with namespace).

## Passthrough

Any first token that isn't a helper goes straight to `kubectl` with the
kubeconfig applied:

```fish
k get pods -A
k apply -f manifest.yaml
k rollout restart deploy/clickhouse -n clickhouse
k scale deploy/kafka -n kafka --replicas=2
k logs <full-pod-name> --previous     # raw kubectl 'logs' (plural)
k describe deploy/foo                  # raw kubectl 'describe'
k exec -it <pod> -- sh                 # raw kubectl 'exec'
```

## Examples

```fish
k pods                     # everything, problems highlighted
k pods kafka               # one namespace
k log kafka -f -g ERROR    # follow kafka logs, filter ERROR
k log worker -p            # previous container's logs (crash loop)
k sh clickhouse            # shell into the clickhouse pod
k sh api env               # run `env` in the api pod
k desc kafka               # describe + events
k ns loadtest              # switch default namespace
k pf clickhouse 8123       # localhost:8123 → pod:8123
```

## Files

- Dispatcher + help: `fish/.config/fish/functions/k.fish` (`k`, `_k_help`)
- Helpers: `fish/.config/fish/functions/_k_{pods,log,sh,desc,ns,pf}.fish`
- Internals: `_k_kubeconfig.fish`, `_k_resolve_pod.fish`,
  `_k_complete_pods.fish`, `_k_complete_ns.fish`
- Completions: `fish/.config/fish/completions/k.fish`

## Notes / gotchas

- No `fzf` dependency: matching is substring-based so it works everywhere. If
  `fzf` is added later, an interactive picker for ambiguous matches is the
  natural upgrade.
- `k ns` writes the namespace into the kubeconfig file (`set-context`), so the
  choice persists across shells using the same config.
- Helpers are internal `_k_*` functions invoked only through `k`; they inherit
  `KUBECONFIG` from the dispatcher. The completion helpers set it themselves
  because completions run them outside `k`.
