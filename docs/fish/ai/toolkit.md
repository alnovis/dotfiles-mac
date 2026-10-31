# AI toolkit reference

> See also: [Architecture](architecture.md) · [Sessions](sessions.md) · [How-to](howto.md)

Command reference for `ai`. For design decisions and the "why" behind these commands, see [architecture.md](architecture.md). For sessions deep-dive (storage layout, context management algorithms), see [sessions.md](sessions.md).

## Contents

- [Quick reference](#quick-reference)
- [Chat & code](#chat--code)
- [Review](#review)
- [Generation](#generation)
- [Sessions](#sessions)
- [Configuration](#configuration)
- [Models](#models)
- [Common flags](#common-flags)
- [Prompt templates](#prompt-templates)
- [Files and paths](#files-and-paths)
- [Environment variables](#environment-variables)
- [Tab-completion](#tab-completion)
- [Troubleshooting](#troubleshooting)

## Quick reference

```
ai [PROMPT]                          one-shot or interactive chat
ai chat [-s NAME | -c]               chat, optionally with persistent session
ai code [-e] [@FILES...]             AI-assisted coding via pi
ai review [PATH | --last N]          code review (auto-detects mode)
ai review --verify-only FILE         re-verify a saved review (no review pass)
ai gen commit                        generate commit message
ai gen summary [DIR]                 generate project summary
ai sessions <subcommand>             manage chat sessions
ai config <subcommand>               view/set provider and model config
ai models <subcommand>               install / manage Ollama models
ai stop [MODEL]                      stop running models
ai --help                            top-level help
```

Each command supports `-h`/`--help`.

## Chat & code

### `ai [PROMPT]`

One-shot prompt to the default provider, or interactive mode if no prompt and no piped stdin.

```
ai "explain monads"                  one-shot
git diff | ai "review this"          pipe stdin as context
ai                                   interactive (terminal only)
```

**Flags:**

| Flag | Effect |
|---|---|
| `-m`, `--model MODEL` | Override resolved model |
| `-t`, `--think` | Enable thinking mode (ollama models that support it) — see note below |
| `--no-think` | Fast path: force `think:false` even on a thinking model (one-shot, ollama provider only) |
| `--agentic` | Let the model explore the current directory with read-only tools — see [Agentic mode](#agentic-mode---agentic). Without `-m` the default model is used, same as the plain provider |
| `--provider PROV` | Override resolved provider (ollama, claude) |
| `--dry-run` | Print assembled prompt to stdout, label to stderr, return 0 without invoking |

`--think` matters mostly in the **interactive REPL**: `ai -t` runs `ollama run --think=true`,
while a plain `ai` runs `--think=false`. In **one-shot** mode it changes little — a
thinking-capable model reasons by default anyway (its reasoning is kept out of the answer,
see [Reasoning sidecar](#reasoning-sidecar)), and a non-thinking model just prints
`ollama: <model> does not support thinking — ignoring --think` to stderr.

### `ai chat`

Interactive chat with the default chat model. Stateless by default — each invocation is a fresh conversation (`ollama run MODEL`).

```
ai chat                              start REPL with task=chat resolved model
ai chat qwen2.5-coder:32b            override model (positional)
```

The positional argument is a **model name**, not a prompt — `ai chat "say hi"` tries to
run a model called `say hi`. For a one-shot prompt use `ai "say hi"`. `ai chat` has no
`--dry-run`.

**Flags:**

| Flag | Effect |
|---|---|
| `-s`, `--session NAME` | Start or resume named session (see [Sessions](#sessions)) |
| `-c`, `--continue` | Resume the last session (read from `.last` pointer) |
| `--new` | When combined with `--session`, error if session already exists |
| `--global` | When creating a new session, force global scope |
| `--system "..."` | System prompt (only applied at session creation) |
| `--model MODEL` | Override model for this run |
| `--provider PROV` | Session mode only — must be ollama |

`--session` and `-c` activate the session pipeline. `--provider claude` with a session is blocked with an error suggesting `claude --resume` / `claude -c`. Without `--session`/`-c`, `--provider` is **ignored**: stateless `ai chat` always runs `ollama run` (for an interactive Claude session use `ai --provider claude`).

### `ai code [OPTIONS] [FILES...]`

Run [pi](https://pi.dev/) with Ollama as the backend. By default file edits are
disabled (`--exclude-tools edit,write`), but `read` and `bash` stay available and pi
prompts before each bash command in interactive mode. This is not a sandbox -- bash
can still touch files, and `-p` (non-interactive) removes the prompt, so avoid it on a
working tree you care about. Use `-e` to allow direct file edits.

```
ai code @src/main.rs                 analyze (no file edits)
ai code -e @src/main.rs              edit mode
ai code --model ollama/qwen2.5-coder:32b @src/
```

Use pi's `@`-syntax to add files or directories to context.

**Flags:**

| Flag | Effect |
|---|---|
| `-e`, `--edit` | Allow file edits (default: edits off via `--exclude-tools edit,write`; bash still available) |
| `--model MODEL` | Pass through to pi (format: `ollama/MODEL`) |
| Any other pi flag | Passed through |

`ai code` is ollama-only — points pi at the resolved code model via `--model ollama/MODEL`. For Claude-assisted coding, use `claude` directly.

### `ai stop`

Stop running Ollama models or the server.

```
ai stop                              stop all running models
ai stop qwen2.5-coder:32b            stop one model
ai stop --server                     kill the Ollama server entirely
```

## Review

`ai review` is a single command with two modes auto-detected from the positional argument:

- **Git mode** — review committed changes (diff vs base, last N commits, specific commit, file filter). The index and working tree are never read — for staged changes use `git diff --staged | ai "review this"`
- **Target mode** — review project or single-file state (filesystem)

### Mode detection

A positional argument is treated as a **target** if it exists on disk (file or directory), otherwise as a **git ref** (branch name).

```
ai review                            git mode: branch vs base
ai review main                       git mode: vs main branch
ai review src/Foo.scala              target mode: file (exists on disk)
ai review src/                       target mode: directory
ai review .                          target mode: current dir
```

### Git mode

| Flag | Effect |
|---|---|
| `--last [N]` | Review last N commits on current branch (default 1) |
| `--commit SHA` | Review one specific commit |
| `--file FILE` | Filter diff to a single file |
| `--max-lines N` | Cap the diff at N lines (default 500) |
| `--context-lines N` | Budget for embedding the **full content** of changed files (default 2000; `0` = diff-only) |
| `--lang-all LANG` | Force language for response AND thinking (slower) |
| (any other) | See [Common flags](#common-flags) and [Review flags for both modes](#review-flags-for-both-modes) |

Examples:

```
ai review                            current branch vs auto-detected base
ai review develop                    vs develop branch
ai review --last 3                   diff of last 3 commits
ai review --commit abc1234           one commit
ai review --file src/Foo.scala       diff filtered to one file
ai review --brief --lang ru          short review in Russian
```

The base branch auto-detection order: `develop` → `main` → `master`.

Diff size cap: 500 lines by default — larger diffs are truncated with a warning. Use `--file` to scope down, or `--max-lines N` to raise the cap for a large commit (e.g. `--max-lines 4000`).

A diffstat of the range under review is always printed to stderr before the run.

**Full changed files (`--context-lines`).** Besides the diff, git mode embeds the whole
content of every changed file (as of the reviewed tip; deleted and binary files are
skipped) so a single-shot model sees the full class / `pom.xml` / `Cargo.toml`, not just
hunks. The total line count of those files is checked against a budget (default 2000,
printed as `Context window: N lines across M files (budget B)`):

- within budget → embedded;
- over budget, interactive terminal → you are asked `[1] diff-only (default)  [2] embed all`;
- over budget, non-interactive → diff-only, with a note suggesting `--context-lines N`.

`--context-lines 0` forces diff-only (smaller prompt — the fix suggested when the model
returns nothing). Embedding is skipped entirely with `--brief` and `--agentic`.

### Target mode

| Flag | Effect |
|---|---|
| `--with-project-context` | For file targets, also include parent project context |
| (any other) | See [Common flags](#common-flags) |

Examples:

```
ai review .                          review current project
ai review ~/work/myproject           review specific project
ai review src/Foo.scala              review one file
ai review src/Foo.scala --with-project-context    file + parent tree+README
ai review . "focus on security"      custom prompt suffix
ai review . --provider claude -o review.md
```

For Claude, target mode `cd`s into the directory so Claude can read files. For Ollama, target context (tree output, README excerpt, file contents) is embedded into the prompt.

### Mode-incompatible flags

The dispatcher validates flag combinations before delegating:

- `--last`, `--commit`, `--file`, `--max-lines`, `--context-lines` require git mode → error if combined with a PATH target.
- `--with-project-context` requires target mode → error if used without a PATH.

`--verify-only FILE` short-circuits both modes (no review pass at all) — see
[Verify an existing review](#verify-an-existing-review---verify-only).

### Review flags for both modes

| Flag | Effect |
|---|---|
| `--lens NAME[,NAME…]` | Add specialist checklist(s) — see [Review lenses](#review-lenses---lens) |
| `--agentic` | Let the model explore the repo with tools — see [Agentic mode](#agentic-mode---agentic) |
| `--no-think` | Fast pass: `think:false` on a thinking model — see [Reasoning sidecar](#reasoning-sidecar) |
| `--verify`, `--no-verify`, `--verify-provider P`, `--verify-model M`, `--verify-output FILE` | Second-opinion pass — see [Verify](#second-opinion-verify---verify) |
| `--verify-only FILE` | Verify a saved review, no review pass |
| `--brief` | Short 3–5 bullet summary — git mode only (target mode rejects it as an unknown option) |
| `--lang LANG` | Response language (long form only — `-l` is not accepted by `ai review`) |

### Review lenses (`--lens`)

A lens injects a specialist hunting checklist into the review, on top of the base
prompt. It tells the model *where to look* for one class of defect; the
finding gate and severity rules in `meta-review*.md` still apply — a lens is not a
mandate to find something. Lenses work in both git and target mode.

```
ai review . --lens access-control          add the authorization checklist
ai review --lens crypto,logic-bug          stack two lenses on the diff
ai review src/Auth.scala --lens access-control,deserialization
ai review --lens rust-async,error-handling review a tokio change
ai review db/ --lens sql-postgres          review migrations / queries
```

Available lenses (comma-separated, stackable) — 15 ship today, in four groups:

**Security** (adapted from Visa's VVAH):

| Lens | Hunts for | Best fit |
|---|---|---|
| `crypto` | JWT alg-confusion, nonce/IV reuse, non-constant-time compares, non-CSPRNG randomness, unenforced TLS verification, hardcoded keys | Anything touching tokens, signing, encryption, TLS |
| `access-control` | IDOR/BOLA, missing `@PreAuthorize`/route guards, privilege escalation, mass assignment, multi-tenant leakage, unscoped bulk ops | APIs, request handlers, anything with authenticated identity + per-object access |
| `logic-bug` | TOCTOU, concurrency on half-initialized state, integer overflow/narrowing, state-machine confusion, tenant-blind cache keys, sentinel-return misuse | Ordering/concurrency-sensitive code, no single grep signature |
| `deserialization` | `ObjectInputStream`, Jackson default-typing, XStream/`XMLDecoder`, SnakeYAML, Kryo/Hessian, allow-list bypass | JVM services (Scala/Java/Kotlin) that read untrusted serialized input |

**Quality** (original to this repo):

| Lens | Hunts for | Best fit |
|---|---|---|
| `documentation` | Docs, comments, examples that drift from what the code does; missing docs on public surfaces | Doc/README changes, public API changes |
| `reactive` | Blocking a non-blocking pipeline, lost/swallowed signals, unbounded buffers, publishers never subscribed | Reactor / WebFlux / reactive Kafka |
| `resource-leak` | Handles not released on every path, especially the error path | JVM code with streams/connections/clients, Reactor lifecycles |
| `error-handling` | Swallowed or mislabeled failures, unchecked `null`/`None`, panics on recoverable input, masked root causes | Scala / Java / Kotlin / Rust |
| `k8s-manifest` | Probes, limits, image tags, secrets — defects that pass `kubectl apply` but bite in prod | k8s / jkube YAML |

**Rust** (original to this repo):

| Lens | Hunts for | Best fit |
|---|---|---|
| `rust-unsafe` | UB / broken safety invariants behind `unsafe`, unsound safe APIs | Crates with `unsafe` blocks or FFI |
| `rust-async` | Lock held across `.await`, blocking the executor, dropped tasks, work lost on cancellation | tokio / async code |
| `rust-ownership` | `Rc` cycles, runtime borrow panics, Drop-order side effects, needless allocations on hot paths | Any Rust code |

**Data / query** (original to this repo — one engine each):

| Lens | Hunts for | Best fit |
|---|---|---|
| `sql-postgres` | Unbounded scans, missing indexes, locking/deadlocks, unsafe migrations, NULL semantics | Postgres queries (inline JDBC/jOOQ/Slick/Doobie) and `.sql` migrations |
| `sql-clickhouse` | `ORDER BY`/partition design, heavy mutations, dedup (`FINAL`) semantics, memory-blowing JOIN/GROUP BY | ClickHouse queries and DDL |
| `hbase` | Row-key hotspotting, unbounded scans, column-family / version growth | HBase Java client / Phoenix |

Each lens carries a **HARD GATE** — e.g. `access-control` requires citing the entry
point + where ownership is checked; `logic-bug` requires citing the trust boundary
crossed. This keeps a lens from turning the reviewer into a false-positive machine.

Lens files live at `~/.config/fish/prompts/lenses/<name>.md` and are overridable;
drop a new `<name>.md` there and it becomes selectable immediately (in `--lens`, its
completion, and validation). Only the four **security** checklists are adapted from
Visa's VVAH (Apache-2.0); the quality, Rust, and data/query lenses are original — see
`lenses/README.md` for attribution. An unknown lens name is an error listing the
available ones. `--lens` is ignored (with a note) in `--brief` mode.

### Second-opinion verify (`--verify`)

A two-pass review: after the first-pass findings, a second pass adversarially tries
to **refute** each one ("assume it is WRONG until confirmed"), then annotates the
output. Nothing is hidden — every finding is kept and tagged, so you decide.

```
ai review --verify                       review, then verify with the same provider
ai review . --lens access-control --verify   lens + verify together
ai review --provider ollama --verify --verify-provider claude   generate locally, verify with claude
```

| Flag | Effect |
|---|---|
| `--verify` | Run the verify pass after the review |
| `--no-verify` | Disable verify (overrides a `review_verify` config default) |
| `--verify-provider P` | Provider for the verify pass (default: `verify_provider` config, else the review provider) |
| `--verify-model M` | Model for the verify pass (default: per-task `verify` config) |
| `--verify-output FILE` | Where the verify pass is written when `-o` is given (default: `<output>.verify.<ext>`) |

Output depends on where the review goes:

- **Terminal (no `-o`)** — the first-pass review verbatim, then a `## Verification`
  section with the verdicts.
- **File (`-o review.md`)** — the raw review is written to `review.md` the moment the
  first pass finishes (so it survives an interrupted verify), and the verify pass goes
  to a **separate** file, `review.verify.md` (`<base>.verify.<ext>`; `report` →
  `report.verify`). `--verify-output FILE` overrides that path. Both paths are printed
  at the end. Without `-o`, `--verify-output` has no effect.

The verify pass emits one keyed verdict per finding — exactly one of the three verdicts,
with the reasoning on a separate `why:` line — and a final tally:

```
- <finding title / file:line> — [CONFIRMED N/10]  ·  [REFUTED N/10]  ·  [UNCERTAIN]
  why: <one or two sentences citing what was found in the code>
Verify: X confirmed, Y refuted, Z uncertain
```

(The `·`-separated line shows the three options; real output carries only one, e.g.
`[REFUTED 9/10]`.)

Verify runs through the same dispatcher (`_ai_run`) as the review, and passes
`--agentic` and `--no-think` through to the verifier. Tool grounding is a property of
the provider (or of the agent runner `--agentic` selects), not of the verify step — see
[Verify and local models](#verify-and-local-models) below. Defaults: opt-in (off unless
`--verify` or a `review_verify` config default), and the `verify` task is configurable
like any other via `ai config` / `ai models use verify MODEL`. `--verify` is skipped
(with a note) in `--brief` mode.

#### Verify and local models

The verify providers behave differently because tool grounding lives in the provider
(or the agent runner), not the verify step:

- **claude** — `claude -p` is agentic: the verify pass reads the actual repo
  (Read/Grep) and walks the call chain to confirm or refute. This is the strong
  path, and it comes for free — no special-casing.
- **ollama, plain** — the provider has no tools, so the verifier reasons from the
  **embedded code** (the diff or single file the first pass saw). It cannot explore
  beyond that.
- **ollama + `--agentic`** — the verifier runs through the agent runner (default: the
  built-in ollama tool loop) and can open files, grep, and list directories in the repo
  itself. See [Agentic mode](#agentic-mode---agentic).

Local models are still unreliable *verifiers* — a small model will confidently claim it
"checked the callers" without doing so, and can refute a real bug as a false positive.
So:

- Best pattern: **generate locally, verify with claude** — cheap local first pass,
  rigorous cloud refutation on a focused set of findings
  (`--provider ollama --verify --verify-provider claude`).
- Weak direction: **claude review → local verify** — a local model refutes cloud
  findings unreliably; the command prints a note suggesting `--verify-provider claude`.

### Verify an existing review (`--verify-only`)

`--verify-only FILE` runs **only** the verify pass over a review you already saved —
no review pass, so a costly claude review can be verified (or re-verified with another
model) without paying to regenerate it. Git/target mode detection is skipped; the
verifier's workdir is the current directory, so run it from the repo when the verifier
is claude or `--agentic` (they read the code from there).

```
ai review --verify-only review.md --provider claude          verify with claude (reads the repo)
ai review --verify-only review.md --verify-model north-mini-code-1.0
ai review --verify-only review.md --file /tmp/change.diff    local verifier + embedded code
ai review --verify-only review.md -o second-opinion.md
```

| Flag | Effect |
|---|---|
| `--verify-provider P` / `--provider P` | Verifier provider (`--verify-provider` wins; then `verify_provider` config; then the review task's provider) |
| `--verify-model M` / `--model M` | Verifier model (`--verify-model` wins; then per-task `verify` config) |
| `--file FILE` | Code / diff to embed for the verifier (otherwise a local verifier reasons from the findings text alone — a note says so) |
| `--verify-output FILE`, `-o FILE` | Output path (`-o` is an alias here; `--verify-output` wins). Default: `<review>.verify.<ext>` next to the review |
| `--agentic`, `--no-think`, `--lang`, `--dry-run` | As for a normal review |

### Agentic mode (`--agentic`)

`--agentic` lets the model **explore the repo with tools** instead of relying only on
what is embedded in the prompt. In git mode it also skips embedding the full changed
files (`--context-lines`) — the diff is still sent, the model fetches the rest itself.

How it is routed (`_ai_run`):

- **claude** — `claude -p` is always tool-grounded, so nothing changes at the provider;
  the flag only skips the changed-file embedding upstream.
- **ollama** — the call goes to an **agent runner** (`_ai_agent_<name>`) instead of the
  plain provider, run inside the repo (the review's workdir), read-only and ephemeral.

The runner is chosen by the `agent` config key (`agent=ollama` by default — set by hand
in `~/.config/ai/config` or a project `.ai/config`; there is no CLI setter):

| `agent` | Runner | Notes |
|---|---|---|
| `ollama` (default) | `_ai_agent_ollama` — built-in `/api/chat` tool loop | Read-only tools `read_file`, `grep`, `find_files`, `list_dir`; `num_ctx` sized per turn to the growing history (capped by the model's native context and `AI_OLLAMA_MAX_CTX`); thinking off; up to 24 turns; live `turn / ctx / elapsed` progress on stderr |
| `pi` | `_ai_agent_pi` — `pi -p` | Read-only allowlist `read,grep,find,ls`, `--no-session`; context governed by `OLLAMA_CONTEXT_LENGTH` on the server and pi's own model config |

```
ai review --agentic                                local model explores the repo for the branch diff
ai review --agentic --verify -o review.md          agentic review + agentic local verify
ai review . --agentic --provider claude            same as without --agentic for claude (always tool-grounded)
```

The agentic path produces no reasoning sidecar (the runner streams its own live
trace instead), and `--no-think` is moot there (the built-in runner already runs with
thinking off).

### Reasoning sidecar

When a review is written to a file (`-o report.md`) and the model is a **thinking**
model (ollama capability `thinking` — e.g. `laguna-xs-2.1`), its reasoning is saved
next to the report as `report.thinking.md` (the verify pass likewise yields
`report.verify.thinking.md`). The report itself stays clean — only the final review,
never the chain-of-thought.

This exists because thinking models otherwise **leak their reasoning into the report**:
omitting the `think` field lets the model dump its chain-of-thought straight into the
answer (prose glued onto the front of the real review). The toolkit now always sends an
explicit `think` boolean — `true` for thinking-capable models (they reason for depth,
but the reasoning is routed to ollama's separate `thinking` channel), `false` for the
rest. The sidecar simply captures that separated channel instead of discarding it.

- The sidecar appears only for thinking models writing to a file. Non-thinking models
  and terminal-streamed reviews produce no sidecar (nothing is created empty).
- The same applies to any ollama call written with `-o`, e.g. `ai gen commit -o msg.txt`
  → `msg.thinking.txt`, `ai gen summary -o draft.md` → `draft.thinking.md`.
- A `↳ reasoning -> <path>` line is printed when one is written.
- It is not produced on the `--agentic` path (the agent runner streams its own live
  turn/tool trace instead).

#### Fast pass: `--no-think`

Reasoning is the bulk of a thinking model's wall-clock time. `--no-think` sends
`think:false` even to a thinking-capable model — a faster, shallower pass (and no
sidecar, since nothing is reasoned). It is threaded through every review path: the
review pass, the verify pass (`--verify`), and `--verify-only`; it also works on a plain
one-shot (`ai --no-think "…"`). It only affects the ollama provider — claude ignores it,
and the agentic runner already runs with thinking off.

```
ai review --no-think                     quick local review with a thinking model
ai review --no-think --verify -o r.md    both passes without reasoning
```

### Deprecated: `ai gen review`

Replaced by `ai review PATH`. The old name shows a yellow deprecation notice and exits non-zero.

## Generation

### `ai gen commit`

Generate a commit message from staged changes (falls back to unstaged if nothing staged).

```
ai gen commit                              from staged diff
ai gen commit --provider claude            via Claude
ai gen commit --lang ru                    Russian
ai gen commit -o /tmp/msg.txt              save to file
ai gen commit --dry-run                    print prompt without invoking
```

Template: [`meta-commit.md`](#prompt-templates).

### `ai gen summary [DIR]`

Generate a concise project summary.

```
ai gen summary                             current dir
ai gen summary ~/work/proj                 specific dir
ai gen summary -o README-draft.md          save to file
ai gen summary --lang ru --provider claude
```

Template: [`meta-summary.md`](#prompt-templates).

### Common to all `ai gen` subcommands

| Flag | Effect |
|---|---|
| `--provider PROV` | Override provider |
| `--model MODEL` | Override model |
| `-l`, `--lang LANG` | Response language (default `en`) |
| `-o`, `--output FILE` | Save output to file |
| `--dry-run` | Print prompt without invoking the model |
| `-h`, `--help` | Show help |

## Sessions

Sessions provide persistent chat history. **Ollama only** — for Claude conversations, use `claude --resume` / `claude -c` directly. See [architecture.md](architecture.md#sessions-a-parallel-pipeline) for why.

Quick start:

```
ai chat --session debug-foo          start (or resume) a named session
ai chat -c                           continue the most recent session
ai sessions ls                       list all sessions
```

Full deep-dive (storage format, context window management, advanced workflows): [sessions.md](sessions.md).

### Subcommands

**Read / browse:**

| Command | Description |
|---|---|
| `ai sessions` / `ai sessions ls [--archived] [--all]` | List sessions (project + global) |
| `ai sessions show NAME` | Render session as markdown |
| `ai sessions info NAME` | Meta + token statistics |
| `ai sessions search QUERY [--name PAT] [--since DATE] [--regex] [--archived\|--all]` | Search across messages (`--archived` = archived only, `--all` = both) |
| `ai sessions stats [--all\|--archived]` | Aggregated counts + tokens (either flag includes archived) |
| `ai sessions export NAME [-f md\|json\|jsonl] [PATH]` | Export to file |

**Modify:**

| Command | Description |
|---|---|
| `ai sessions rm NAME [-f]` | Delete session |
| `ai sessions rename OLD NEW` | Rename |
| `ai sessions clear NAME [-f]` | Wipe messages, keep meta |
| `ai sessions edit NAME` | Open in `$EDITOR` |

**Lifecycle:**

| Command | Description |
|---|---|
| `ai sessions branch SRC [NEW]` | Fork a session (NEW auto-named `SRC-branch-N` if omitted) |
| `ai sessions archive NAME` | Move to `archived/` subdir |
| `ai sessions restore NAME` | Un-archive |
| `ai sessions move NAME --to {project\|global}` | Relocate between scopes |
| `ai sessions import PATH [--name NEW] [--global]` | Import a session file |

**Pinning:**

| Command | Description |
|---|---|
| `ai sessions pin NAME --model M` | Lock the model for this session (`--model` required) |
| `ai sessions unpin NAME` | Remove pin |

A pinned session uses the pinned model regardless of task-level config or `AI_DEFAULT_MODEL`. Sessions are ollama-only, so only the model is pinned: `--provider ollama` is accepted (and recorded), any other `--provider` is an error. Override for one REPL run with an explicit `ai chat -s NAME --model M`.

## Configuration

`ai config` manages provider and model defaults at three layers: global, project, and per-task. See [architecture.md](architecture.md#configuration) for the resolver chain.

### View

```
ai config                            show project + global sections side-by-side
ai config status                     resolved per-task with origin annotations
ai config provider                   show resolved global provider
ai config provider --task review     show resolved provider for one task
ai config tasks                      list known task identifiers
```

`ai config status` output includes per-task resolved values with origin tags. Provider origins: `project`, `global` (a per-task key), `project+top` / `global+top` (inherited from the top-level `provider=` key of that layer), `default`. Model origins: `project`, `global`, `env` (`AI_DEFAULT_MODEL`), `default` (hardcoded `qwen3.5:9b`), or `—` (non-ollama provider with no model set → the provider's own default). Use it to answer "why is `ai review` using claude?"

A per-task `<task>_model` is used **only while the task's configured provider is the one
in use** — a model name is provider-specific, so `--provider` overriding to a different
provider drops it. The flip side: after `ai config provider claude --task review`, an
existing `review_model` (say an ollama tag) is now handed to claude. Set a matching
model (`ai models use review sonnet`) or clear the old one first
(`ai config reset --task review`, which removes both `review_provider` and `review_model`).

### Set

```
ai config provider claude                              global
ai config provider claude --task review                global, per-task
ai config provider claude --task review --project      project, per-task
ai config provider ollama --task commit,summary        comma-list applies to multiple tasks
```

| Flag | Effect |
|---|---|
| `--task X` | Apply to a task (or comma-list, or `all`) |
| `--project` | Write to project config instead of global |

### Reset

```
ai config reset --task review                          clear global per-task review keys
ai config reset --task review --project                clear project per-task review keys
ai config reset --task all                             clear all global per-task keys
ai config reset --task all --project                   clear all project per-task keys
```

### Move

Move per-task keys between project and global layers:

```
ai config move --task review --to project              global → project
ai config move --task review --to global               project → global
ai config move --task all --to project                 every per-task key, global → project
```

Behavior: read keys from the **opposite** layer, write to `--to`, remove from source. If both layers had the key (conflict), the source value wins.

### Keys without a CLI setter

A few keys are read from the same files (project walk-up, then global) but have no
`ai config` subcommand — add the line by hand:

| Key | Values | Effect |
|---|---|---|
| `review_verify` | `1` / `true` / `yes` / `on` | Run the verify pass by default on `ai review` (opt out with `--no-verify`) |
| `agent` | `ollama` (default) \| `pi` | Agent runner behind `--agentic` for ollama — see [Agentic mode](#agentic-mode---agentic) |
| `sessions_recent_turns`, `sessions_token_threshold`, `sessions_summary_model` | see [sessions.md](sessions.md#config-knobs) | Session context management |

`verify_provider` / `verify_model` are ordinary per-task keys (`--task verify`).

## Models

`ai models` manages Ollama models — install, set defaults, browse the catalog.

### List

```
ai models                            equivalent to `ai models list`
ai models list                       filtered by RAM (hide oversized models by default)
ai models list --all                 show everything
ai models list coder                 filter by substring in name
```

The list output has two extras for the per-task system:

- **Active selection** block: shows what `ai chat`, `ai code`, etc. would resolve to right now.
- **Used for** column: tags models that are explicitly bound to a task (e.g. `commit`, `default`).

Models are **grouped by label**: each label gets its own group (alphabetical), and
unlabeled models fall into **General**, printed last.

### Labels

```
ai models label --seed                         auto-label from names (coder/devstral → coding, vl/vision → vision)
ai models label ornith:9b coding               set one model's label
ai models unlabel ornith:9b                    back to General
ai models labels                               show the model → label map
```

Labels are lowercased; one label per model; `label MODEL general` just clears it.
`--seed` never overwrites a label you set. A bare name and its `:latest` form match the
same label. Stored in `~/.config/ai/model-labels` as `MODEL=label` lines.

### Install / use / remove

```
ai models install qwen3.5:9b                          pull from ollama.com
ai models rm codellama:13b                            remove
ai models use qwen3.5:9b                              set as global default (sets AI_DEFAULT_MODEL)
ai models use code qwen2.5-coder:32b                  per-task default (TASK MODEL, positional)
ai models use review,verify north-mini-code-1.0       several tasks at once
ai models use all qwen3.5:27b                         every task
ai models use qwen2.5-coder:7b --task commit --project   flag form, project-scoped
```

`ai models use` takes either form:

| Form | Meaning |
|---|---|
| `use MODEL` | Global default (`AI_DEFAULT_MODEL`) — MODEL must be installed |
| `use TASK MODEL` | One task, or a `comma,list`, or `all` |
| `use MODEL --task TASK` | Same as `use TASK MODEL` (flag form, kept) |
| `… --project` | Write the per-task value to the project `.ai/config` (requires a TASK) |

TASK is one of: `chat, code, review, verify, commit, summary, all`. A lone task name with no model errors instead of being misread as a model; an unknown task errors instead of being silently ignored. Per-task values are trusted as-is (you may set a claude-side model name when the task uses claude); the global default is validated against installed models. See `ai models use --help`.

### Maintenance

```
ai models update                     re-pull all installed models to latest tag
ai models info qwen2.5-coder:32b     params, quantization, context window
ai models prune                      clean up partial downloads and orphaned blobs
ai models running                    show currently loaded models (`ollama ps`)
```

## Common flags

These appear on multiple commands:

| Flag | Where | Effect |
|---|---|---|
| `--provider PROV` | All generation/review/chat | Override resolved provider |
| `--model MODEL` | All generation/review/chat | Override resolved model |
| `--lang LANG` | gen, review | Response language code (`en`, `ru`, `de`, etc.). `-l` works for `ai gen` only — `ai review` takes the long form |
| `-o`, `--output FILE` | gen, review | Save output to file |
| `--dry-run` | top-level `ai`, gen, review | Print assembled prompt without invoking (not available on `ai chat`) |
| `--no-think` | top-level `ai`, review | Force `think:false` on a thinking model (fast pass) |
| `--agentic` | top-level `ai`, review | Explore the repo with tools (agent runner for ollama) |
| `--task X` | config, models use | Scope to one or more tasks |
| `--project` | config, models use | Operate on project layer |
| `--to project\|global` | config move, sessions move | Target layer / scope |
| `-h`, `--help` | All | Show help |

`--lang` writes "respond in $lang" preamble into the prompt. `--lang-all` (review only) extends this to "thinking should also be in $lang" for thinking models — slower and rarely needed.

## Prompt templates

Located in `~/.config/fish/prompts/`. Each is symlinked from the dotfiles repo via `stow` and is user-editable. Commands load them at runtime; deleting a template falls back to a minimal inline default.

| File | Used by |
|---|---|
| `meta-commit.md` | `ai gen commit` |
| `meta-summary.md` | `ai gen summary` |
| `meta-review.md` | `ai review PATH` (target mode) |
| `meta-review-diff.md` | `ai review` (git mode) |
| `meta-verify.md` | Verify pass (`ai review --verify`, `--verify-only`) |
| `meta-session-summary.md` | Rolling summary in long sessions |
| `lenses/<name>.md` | `ai review --lens NAME` (one checklist per file; `lenses/README.md` is not a lens) |

Iterate freely — changes take effect on the next invocation. No fish reload needed (templates are read fresh each time).

## Files and paths

| Path | What |
|---|---|
| `~/.config/ai/config` | Global config (`provider`, `<task>_provider`, `<task>_model`, sessions params) |
| `<project>/.ai/config` | Per-project config (walk-up from PWD; see [architecture.md](architecture.md#configuration)) |
| `~/.config/ai/sessions/<name>.jsonl` | Global session storage |
| `<project>/.ai/sessions/<name>.jsonl` | Project session storage |
| `~/.config/ai/sessions/.last` | Pointer to most recent global session |
| `<project>/.ai/sessions/.last` | Pointer to most recent project session |
| `<report>.thinking.<ext>` | Reasoning sidecar next to a report written with `-o` (thinking models only) |
| `<report>.verify.<ext>` | Verify-pass output next to a review written with `--verify -o` (or by `--verify-only`) |
| `<report>.verify.thinking.<ext>` | Reasoning sidecar of the verify pass |
| `~/.config/ai/model-labels` | `MODEL=label` map used to group `ai models list` (`ai models label`) |
| `~/.config/fish/prompts/meta-*.md` | Prompt templates (symlinked from dotfiles) |
| `~/.config/fish/prompts/lenses/*.md` | Review lenses (symlinked from dotfiles) |
| `~/.cache/ai-models.json` | Local installed-models cache |
| `~/.cache/ai-registry.json` | Ollama catalog cache |
| `~/.cache/ai-context-windows.json` | Per-model context-window cache (sessions) |

## Environment variables

| Variable | Read by | Effect |
|---|---|---|
| `AI_DEFAULT_MODEL` | resolver chain | Legacy global model default (universal var, settable via `ai models use MODEL`) |
| `AI_OLLAMA_MAX_CTX` | ollama provider, built-in agent runner | RAM-safe ceiling for the per-request `num_ctx` (default 131072). The provider sizes `num_ctx` to the prompt (+8k output reserve) and **fails loudly** if that exceeds the ceiling instead of truncating; the agent runner clamps to `min(model native max, this)`. Raise only if you have the RAM |
| `OLLAMA_HOST` | ollama provider, built-in agent runner | Server address (`host:port` or URL; default `http://localhost:11434`). Sessions and model-info helpers hard-code `localhost:11434` |
| `OLLAMA_CONTEXT_LENGTH` | Ollama server itself | Default context (`env.fish`, 131072). Governs the **pi** agent runner and `ollama run` (`ai`, `ai chat` REPLs); the ollama provider and the built-in agent runner set `num_ctx` per request and ignore it. Raise for bigger pi runs (KV-cache RAM cost); models cap at their native max |
| `EDITOR` / `VISUAL` | `ai sessions edit` | Editor for raw JSONL editing |
| `ANTHROPIC_API_KEY` | Not used by this toolkit | Claude CLI manages its own auth via web login |

## Tab-completion

`completions/ai.fish` provides context-sensitive completions:

- Top-level subcommands
- Subcommands of `gen`, `models`, `config`, `sessions`
- Flag names per subcommand
- Provider names (from `_ai_providers` — auto-discovers all installed providers)
- Task names (`chat`, `code`, `review`, `verify`, `commit`, `summary`)
- Lens names for `ai review --lens` via `_ai_complete_lens` (names from `_ai_review_lens`, which auto-discovers `prompts/lenses/*.md`). Stacks: after `--lens crypto,` it offers `crypto,<next>` and skips lenses already chosen
- Session names for `ai sessions show/info/rm/...` and `ai chat -s ...`
- Model names via `_ai_complete_models` for `--model`, `--verify-model`, `ai chat MODEL`, `ai models use/rm/info/label/unlabel`, `ai sessions pin --model`. Reads the installed-models cache, so it works with the Ollama server **down** (falls back to `ollama list` only if the cache is cold); `--verify-model` additionally offers the Claude aliases `sonnet`, `opus`, `haiku`
- Scope values (`project`, `global`) for `ai config move`, `ai sessions move`

All completions are recomputed at tab time — no static lists to update.

## Troubleshooting

**`Error: claude is not installed`**

`claude` CLI not on `$PATH`. Install via web login flow at claude.ai/code or set up Anthropic API access (note: API access has been gated; toolkit doesn't bridge to API directly — see [architecture.md](architecture.md#boundaries-and-what-we-deliberately-dont-do)).

**`Error: --session requires NAME (or use -c to continue last)`**

`ai chat --session` without a name only works as `-c` (continue last). To start fresh, pass an explicit name: `ai chat -s my-session`.

**`Error: sessions are supported for ollama provider only`**

You triggered the session pipeline with a claude-resolved task. Either use ollama for this session, or use `claude --resume` / `claude -c` for Claude conversations.

**`Error: --last is git-mode only and cannot combine with a path target`**

`ai review --last 3 some/path` is invalid. `--last` is git-mode-only. Choose one or the other.

**`Ollama is not running`** from `ai stop`

Only `ai stop` prints this (it checks `pgrep ollama` and has nothing to stop). Every
command that needs the server goes through `_ai_ensure_running`, which **auto-starts**
`ollama serve` in the background (`Starting Ollama...` on stderr) and waits up to 10s;
if that fails you get `Error: Ollama failed to start`. If Ollama runs under a different
process name (rare), the `pgrep` check misses it — start it manually with `ollama serve &`.

**`ollama: prompt ~N tokens needs ~M context, over the 131072 ceiling`**

The ollama provider refuses to truncate a too-large single-shot prompt (the model would
return nothing). Shrink it — `ai review --context-lines 0` (diff-only), `--file`, a
smaller range — or raise `AI_OLLAMA_MAX_CTX` if you have the RAM. `--agentic` is another
way out: the model fetches context on demand instead of receiving it all up front.

**`[ctx_truncated kept=N total=M budget=X]` appears in a session**

Sliding window kicked in — older turns were dropped. If you want to preserve them: raise `sessions_recent_turns` or `sessions_token_threshold` in config, or use `ai sessions branch` to fork before the truncation happens. The rolling summary will catch facts from dropped turns into a `summary` block — see [sessions.md](sessions.md#context-management).

**Tab completion not picking up a new provider**

Provider plugins are autoloaded on first call. After adding `_ai_provider_<name>.fish`, run any `ai` command once (e.g. `ai config provider`) to trigger autoload, then completion will see it. If using stow, also run `stow --restow fish` to symlink the new file.

**`broken symlinks in ~/.config/fish/functions/`**

After deleting files from the repo (e.g. an old `_ai_*` function), the stow symlinks become broken. Clean up with:

```
find ~/.config/fish/functions/ -maxdepth 1 -type l ! -exec test -e {} \; -print -delete
```

This is also automatic if you re-run `stow --restow fish` after the deletion.
