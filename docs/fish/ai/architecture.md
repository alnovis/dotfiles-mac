# AI toolkit architecture

> See also: [Toolkit reference](toolkit.md) · [Sessions](sessions.md) · [How-to](howto.md)

This document describes the design of the `ai` toolkit — its layers, contracts, and the invariants that should remain true as the code evolves. Command names appear only as illustrations; user-facing behavior is documented in [toolkit.md](toolkit.md).

## Goals

The `ai` toolkit is a fish-native CLI front-end to multiple AI providers. It exists to:

1. Give one consistent command surface regardless of underlying provider (Ollama, Claude, future providers).
2. Persist preferences (provider, model, prompts) per task and per project — not just globally.
3. Support stateful conversations (sessions) for providers that don't have native session management.
4. Keep prompt engineering user-editable without touching shell code.
5. Stay fish-shell idiomatic — autoloaded functions, no heavy dependencies, `stow` symlinks.

The architecture is a stack of independent layers. Each layer has one responsibility, knows about the layer directly below it, and exposes a stable contract upward.

## System overview

```mermaid
flowchart TD
    subgraph L5["Layer 5 — command handlers"]
        cmd_gen["ai gen commit<br/>ai gen summary<br/>ai review"]
        cmd_chat["ai chat<br/>ai code"]
        cmd_sess["ai chat --session<br/>ai sessions ..."]
    end

    subgraph L4["Layer 4 — prompt assembly"]
        assembly["template + language prefix<br/>+ provider-specific context"]
    end

    subgraph L3["Layer 3 — dispatcher"]
        dispatch["_ai_run<br/>provider selection, --agentic routing,<br/>workdir, output, dry-run"]
    end

    subgraph L2["Layer 2 — plug-ins (auto-discovered)"]
        p_ollama["_ai_provider_ollama"]
        p_claude["_ai_provider_claude"]
        a_ollama["_ai_agent_ollama<br/>(agent runner, default)"]
        a_pi["_ai_agent_pi<br/>(agent runner)"]
    end

    subgraph L1["Layer 1 — external tools"]
        t_ollama["ollama server<br/>/api/generate, /api/chat,<br/>ollama show / run"]
        t_claude["claude CLI<br/>claude -p"]
        t_pi["pi CLI<br/>pi -p"]
    end

    sessions_pipeline["sessions pipeline<br/>(parallel — see below)"]

    cmd_gen --> assembly
    assembly --> dispatch
    cmd_chat --> dispatch
    cmd_sess --> sessions_pipeline
    dispatch --> p_ollama
    dispatch --> p_claude
    dispatch -.->|"--agentic (ollama)"| a_ollama
    dispatch -.->|"--agentic, agent=pi"| a_pi
    sessions_pipeline -.-> t_ollama
    p_ollama --> t_ollama
    a_ollama --> t_ollama
    a_pi --> t_pi
    p_claude --> t_claude
```

(Simplification: of the interactive entry points, only top-level `ai` goes through
`_ai_run`. Stateless `ai chat` runs `ollama run MODEL` itself, and `ai code` calls
`_ai_agent_pi --interactive` directly.)

**Layer responsibilities (bottom-up):**

| Layer | Responsibility | Knows about |
|---|---|---|
| 1 (boundary) | The external tool itself | — (external) |
| 2 (plug-ins) | How to invoke this specific tool — a *provider* answers from the prompt; an *agent runner* explores the repo with tools | The tool's CLI/API |
| 3 (dispatcher) | Provider selection, `--agentic` routing, workdir, output, dry-run | All providers and runners via discovery |
| 4 (prompt assembly) | Build the prompt with context for the chosen provider | The task domain + provider capabilities |
| 5 (command handler) | The user-facing command | The task (commit/review/etc) |

Sessions sit beside this stack as a parallel pipeline with its own storage and context management — described in [sessions.md](sessions.md).

## Layer 2: provider plugins

The toolkit treats providers as plug-ins. Each provider is a single fish function named `_ai_provider_<name>` that knows nothing about the broader system — only how to invoke its specific tool.

**Contract** (called by the dispatcher):

```
_ai_provider_<name> [--interactive] [--model M] [--think] [--agentic]
                    [--no-think] [--thinking-output FILE]     (ollama only)

Non-interactive (default):
  reads stdin (prompt + piped input as a single stream)
  writes the response to stdout
  returns the tool's exit status

Interactive (--interactive):
  takes over TTY (no stdin to consume)
  ignores --model if the tool doesn't support one
```

`--think` and `--agentic` are accepted by every provider for interface symmetry. claude
ignores `--think`, and `--agentic` is a no-op for it (`claude -p` is always tool-grounded).
The ollama provider gates thinking on the model's capability (from `ollama show`): a
thinking-capable model gets `think:true` by default, and `--think` on a non-thinking model
prints a warning (`does not support thinking — ignoring --think`) rather than failing.
`--no-think` and `--thinking-output` exist only on the ollama provider; the dispatcher
forwards them only when it dispatches there.

**The ollama provider** talks to the server over HTTP, not the CLI: non-interactive calls
POST to `/api/generate` with `stream:true` and an explicit `think` boolean, size
`options.num_ctx` to the prompt (≈chars/3 + 8k output reserve, floor 8k, ceiling
`AI_OLLAMA_MAX_CTX` = 131072 by default — over the ceiling it errors instead of
truncating), and stream `.response` through `jq --unbuffered`. With `--thinking-output`
the `.thinking` channel is written to that file (the reasoning sidecar). It honors
`OLLAMA_HOST`. Interactive mode uses `ollama run --think=true|false`. `/api/chat` is used
only by the sessions pipeline and the built-in agent runner.

**Discovery.** `_ai_providers` enumerates plugin functions via `functions -an`, filters to names matching `^_ai_provider_(?<name>.+)$`, then validates each is loadable with `functions -q`. The result is the canonical list of available providers — used by completions, config validation, and the dispatcher.

**Adding a provider.** Create one file:

```
fish/.config/fish/functions/_ai_provider_<name>.fish
```

It is picked up automatically. No registration step, no code changes elsewhere. The function is autoloaded on first invocation by fish. Internal helpers that are not providers deliberately avoid the `_ai_provider_` prefix (e.g. `_ai_ollama_chat`, `_ai_agentic_native`), so `_ai_providers` returns exactly `claude ollama`.

### Agent runners (second plug-in family)

A provider answers from the prompt alone; an **agent runner** explores the repo with
tools. Runners are discovered the same way — `_ai_agents` lists `_ai_agent_<name>`
functions (today: `ollama`, `pi`).

```
_ai_agent_<name> [--interactive] [--provider P] [--model M] [--no-session] [--edit] ...

Non-interactive: reads the prompt from stdin, streams the final answer to stdout,
                 live progress to stderr. Read-only unless --edit.
```

- `_ai_agent_ollama` — the default. Drives ollama's `/api/chat` tool-calling loop itself
  with four read-only tools (`read_file`, `grep`, `find_files`, `list_dir`) executed in
  the working directory (relative paths; not a sandbox — absolute paths are not
  rejected; outputs are byte-capped), re-sizing `num_ctx` every turn to the growing history (clamped
  to `min(model native context, AI_OLLAMA_MAX_CTX)`), thinking off, max 24 turns.
- `_ai_agent_pi` — wraps `pi -p` with a read-only allowlist (`read,grep,find,ls`) and
  `--no-session`; context is the server's static `OLLAMA_CONTEXT_LENGTH`. `ai code` also
  uses it, interactively, with its own tool policy.

`_ai_agentic_native PROVIDER` says whether a provider is already tool-grounded (today:
`claude`) and therefore needs no runner. `_ai_default_agent` picks the runner: the `agent`
config key (project → global), default `ollama`. Adding a runner is one
`_ai_agent_<name>.fish` file plus `agent=<name>` in config.

## Layer 3: dispatcher

`_ai_run` argparses common flags (`--provider`, `--model`, `-t/--think`, `--no-think`, `--agentic`, `--workdir`, `--output`, `--thinking-output`, `--dry-run`), takes the provider from `--provider` or else the **top-level `provider` key only** (`_ai_config_read provider`, default `ollama` — per-task resolution is the caller's job, see [Per-task resolution](#per-task-model-and-provider-resolution)), validates it via `functions -q _ai_provider_$provider`, then:

- If `--dry-run`: prints the assembled prompt to stdout, label to stderr, returns 0 without invoking the plugin.
- Picks the dispatch target: normally the provider. With `--agentic` on a provider that is **not** natively tool-grounded (`_ai_agentic_native` false — i.e. ollama), it dispatches to `_ai_agent_<agent>` instead, passing `--provider P --no-session [--model M]` (the runner does not take `--think`/`--agentic`).
- Forwards `--no-think` and the reasoning-sidecar path (`--thinking-output`) only when the target is `_ai_provider_ollama`. For a direct `--output` on ollama (non-agentic) it derives the sidecar path itself, reports it, and deletes it if empty.
- If interactive (no prompt, no piped stdin, no output redirect): calls the target with `--interactive`.
- Otherwise: pipes `_ai_pipe_input "$prompt"` (which emits the prompt argument followed by stdin if piped) into the target, and redirects stdout to the `--output` file — or, with no file, simply inherits fd 1. It deliberately does **not** write via `/dev/stdout`: that reopens the controlling terminal and escapes an enclosing pipe (e.g. `_ai_run_watched`'s `tee`).

`--workdir` is honored at the dispatcher level: `cd` before invocation, restore original PWD on exit. This is how Claude — and an agent runner under `--agentic` — reads project files in `ai review` (both modes).

`_ai_run_watched` wraps `_ai_run` for file output with a progress readout: one foreground pipeline (`_ai_run | tee FILE`) so Ctrl-C reaches `curl` and actually stops the model; on the agentic path it lets the runner's own live trace through instead.

## Configuration

Configuration is not a layer of the stack above — it is a set of pure resolvers that the dispatcher (Layer 3) and the command handlers (Layer 5) consult. It is layered, not monolithic. A value can be set globally, scoped to a project, or scoped to a specific task. The resolver returns the most specific match.

**Files:**

| Location | Scope | Owns |
|---|---|---|
| `<project>/.ai/config` (walk-up) | Project | Per-project + per-task-per-project overrides |
| `~/.config/ai/config` | Global | Global + per-task global overrides |
| `$AI_DEFAULT_MODEL` env | Shell | Legacy global model fallback |

**Format.** Plain `key=value` lines. Schema:

| Key | Scope | Notes |
|---|---|---|
| `provider` | Top-level | Default provider for unspecified tasks |
| `<task>_provider` | Per-task | Override for a specific task |
| `<task>_model` | Per-task | Model for a specific task — used only while the provider in use is the task's configured provider |
| `review_verify` | Review | Truthy (`1`/`true`/`yes`/`on`) → `ai review` runs the verify pass by default |
| `agent` | Agentic | Agent runner behind `--agentic` for non-native providers: `ollama` (default) or `pi` |
| `sessions_recent_turns` | Sessions | Sliding-window target |
| `sessions_token_threshold` | Sessions | Truncation threshold (fraction of context window) |
| `sessions_summary_model` | Sessions | Override model used for rolling summary |

`review_verify`, `agent`, and the `sessions_*` keys have no `ai config` setter — they are edited by hand.

Known tasks: `chat`, `code`, `review`, `verify`, `commit`, `summary` (enumerated by `_ai_tasks`). The `verify` task configures the second-opinion pass of `ai review --verify` independently of the review task itself (so you can review with one provider/model and verify with another).

**Walk-up resolution.** Project config is discovered by `_ai_project_config_file`: from `$PWD`, walk up the directory tree checking each ancestor for `.ai/config`. Stop conditions, in order:

1. `$dir == $HOME` or `$dir == /` → no project config.
2. `$dir/.ai/config` exists → return it.
3. `$dir/.git/` exists → check this dir only (git root is the project boundary), then stop.

This means a session or config can live at the git root and apply to all subdirectories without explicit per-folder setup.

**Read resolver chain** (`_ai_config_read KEY`):

```
1. project .ai/config → if KEY present, return it
2. ~/.config/ai/config → if KEY present, return it
3. (caller falls back to env var or hardcoded default)
```

This is implemented in a single function and shared by all higher-level resolvers (`_ai_default_provider`, `_ai_default_model`, `_ai_origin_*`).

**Write target.** Writes don't follow the same chain — they go to one specific file:

- Without `--project`: always `~/.config/ai/config`.
- With `--project`: `_ai_project_config_target` returns either the existing project config path (if walk-up finds one) or computes a new one (`<git-root>/.ai/config`, or `<cwd>/.ai/config` if not in a repo).

So once a project has a `.ai/config`, both reads and writes to it are sticky.

**`move` semantics.** `ai config move --task X --to {project|global}` is shorthand for "read keys from the opposite layer, write to the target layer, remove from source". Conflict resolution: target's value is overwritten by source's. The user said "move", which means the source value wins.

## Per-task model and provider resolution

Tasks are an axis of personalization. The user may want:

- `chat` → ollama qwen3.5:9b (fast)
- `code` → ollama qwen2.5-coder:32b (specialized)
- `review` → claude (better at judgment)
- `commit` → ollama qwen2.5-coder:7b (small + fast for short messages)

Each command handler knows its task identifier and passes it into resolvers.

**Resolver contract:**

```fish
_ai_default_provider [TASK]
  TASK   optional task identifier
  Returns: provider name (always non-empty)
  Chain:
    1. <task>_provider from config (if TASK given)
    2. provider from config
    3. "ollama"

_ai_default_model [TASK] [PROVIDER]
  TASK     optional task identifier
  PROVIDER optional provider hint
  Returns: model name (may be empty for non-ollama)
  Chain:
    1. <task>_model from config (if TASK given) — only if PROVIDER is
       unspecified or equals _ai_default_provider TASK (a model name is
       provider-specific, so a --provider override must not leak it)
    2. $AI_DEFAULT_MODEL env (only if PROVIDER is ollama or unspecified)
    3. Hardcoded fallback "qwen3.5:9b" (only if PROVIDER is ollama or unspecified)
  Non-ollama with no per-task model → empty result; caller passes no
  --model and lets the provider use its native default.
```

The provider-match guard cuts both ways: switching a task's provider (`ai config provider claude --task review`) makes an existing `review_model` apply to the *new* provider, so the two keys should be changed together.

**Origin tracking** (`_ai_origin_provider`, `_ai_origin_model`) mirrors the same logic but returns a label instead of the value. Provider labels: `project`, `global` (per-task key), `project+top`, `global+top` (inherited from that layer's top-level `provider`), `default`. Model labels: `project`, `global`, `env`, `default`, or `—` (non-ollama provider, no model → provider default). This is what powers the resolved view (`ai config status`).

**Where callers use this.** Each command handler resolves before any side effects:

```
provider = --provider flag       OR _ai_default_provider <task>
model    = --model flag          OR _ai_default_model <task> <provider>
```

This pre-resolution happens BEFORE any `cd $workdir` or session loading, so resolvers see the user's invocation PWD (not the internal workdir).

## Layer 4: prompt templates

Prompts are user-editable, not buried in shell code. Each generation/review command has a template file:

```
~/.config/fish/prompts/
├── meta-commit.md           (ai gen commit)
├── meta-summary.md          (ai gen summary)
├── meta-review.md           (ai review PATH — target mode)
├── meta-review-diff.md      (ai review — git mode)
├── meta-verify.md           (verify pass: ai review --verify / --verify-only)
├── meta-session-summary.md  (rolling summary for long sessions)
└── lenses/                  (ai review --lens NAME — one <name>.md checklist each,
                              discovered by _ai_review_lens; README.md excluded)
```

(These are symlinked from the dotfiles repo via stow.)

**Loader pattern.** Every command that uses a template follows the same shape:

```fish
set -l template_file ~/.config/fish/prompts/meta-<name>.md
set -l prompt
if test -f $template_file
    set prompt (cat $template_file | string collect)
else
    set prompt "<minimal inline fallback>"
end
```

If the user deletes or moves a template, the command still works with a compact built-in default. The user can iterate on prompt engineering without touching fish code, just by editing the `.md` file.

**Where assembly happens.** Templates are the "what to say" part. Assembly (combining template + context + language instruction + custom user prompt + the actual content) is the responsibility of each command handler (Layer 5). See [Layer 4: provider-specific assembly](#layer-4-provider-specific-assembly).

## Layer 4: provider-specific assembly

Different providers have different capabilities. Claude CLI can read files from the working directory. The ollama provider (invoked via HTTP API) has no filesystem access — unless `--agentic` routes the call to an agent runner. The prompt assembly must reflect that.

**The split.** Inside a command handler:

- Common: load template, resolve task model, build language prefix, attach custom prompt suffix.
- Provider-specific: build the final `full_prompt` string.
  - **Claude**: just the template + custom instructions. Tell it to review/summarize the target. The actual file content is read by Claude itself (it has access to the working directory).
  - **Ollama**: template + embedded context (tree output, README excerpt, file content; in git-mode review, the full changed files within the `--context-lines` budget). Everything plain Ollama needs must be in the prompt because it cannot read files.
  - **`--agentic`** (git-mode review): the full-changed-files embed is skipped — the diff is still sent, and the model (claude, or ollama via an agent runner) fetches the rest itself.

**Where the workdir matters.** `_ai_run --workdir DIR` does the `cd` before invoking the provider, so Claude sees the right directory. For plain ollama the cd happens too but is irrelevant (no files are read at runtime). For ollama **with `--agentic`** it matters just as much as for Claude: the agent runner's tools operate relative to that directory.

**Why this split is right.** The provider plugin layer (Layer 2) handles HOW to invoke each tool. The prompt assembly (Layer 4–5) handles WHAT to send. Mixing them would either:

- Force the runner to know about file contents (leaking into Layer 2), or
- Force the prompt to embed content even for Claude (wasteful and weakens Claude's exploration).

By keeping the split — context assembly in the command handler, invocation in the plugin — both providers get what they need without the layers leaking into each other.

## Sessions: a parallel pipeline

Sessions are a separate concern from one-shot commands. They have their own storage, their own context management, and their own provider boundary.

**Architectural decision: sessions are ollama-only.**

Claude has its own native session story (`claude --resume`, internal storage in `~/.claude/projects/`). The toolkit deliberately does NOT bridge to it. Reasons:

- **Abstraction integrity.** A bridge would surface "what works for ollama doesn't work for claude" inconsistencies. Better to have one clean feature (ollama sessions) and let claude users go to claude CLI for its own session story.
- **Don't depend on another product's internals.** Claude's storage format is private API. Parsing it would create unmaintainable coupling.
- **Symmetric with how the toolkit treats other tools.** We don't manage pi's sessions, opencode's memory, or future cline's Kanban. Each tool owns its territory.

When the user passes `--session NAME --provider claude` (or task resolution selects claude), the command errors with a clear redirect to `claude --resume` / `claude -c`.

**Pipeline overview:**

```mermaid
flowchart TD
    stdin["user input (stdin)"]
    repl["_ai_session_chat<br/>REPL outer loop"]
    maybe["_ai_session_maybe_summarize<br/>side effect: appends {t:summary} row"]
    build["_ai_session_build_messages<br/>pure: reads file → JSON array"]
    api["_ai_ollama_chat<br/>streaming /api/chat"]
    append["append {t:assistant} row"]
    jsonl[(".ai/sessions/&lt;name&gt;.jsonl<br/>append-only JSONL")]

    stdin --> repl
    repl --> append_user["append {t:user} row"]
    append_user --> maybe
    maybe --> build
    build --> api
    api --> append
    append --> jsonl
    maybe -.write.-> jsonl
    append_user -.write.-> jsonl
    build -.read.-> jsonl
```

Storage layout, JSONL types, the `covers` field, and the truncation algorithm are documented in detail in [sessions.md](sessions.md). The architectural points here are:

1. **Append-only JSONL** for concurrency tolerance and append atomicity.
2. **Side-effect separation.** `build_messages` is pure (read → return array). `maybe_summarize` is the side-effect step (write to file). Calling them in order keeps the contract clean.
3. **Walk-up symmetric with config.** Sessions and config use the same walk-up algorithm. Same boundaries (git root, $HOME, /).
4. **`covers` field as durable cursor.** A summary block records how many turn messages it covers. The builder skips that many on next call. No external pointer to maintain.

## Design invariants

These should stay true as the code evolves:

1. **One-shot stateless paths stay backward-compatible.** Adding sessions did not change `ai chat`, `ai gen commit`, `ai review --last 3`. The new code path is additive.

2. **Adding a provider is one file.** No registration in `_ai_providers` or other index. Discovery is via `functions -an`. A new file in `functions/` is sufficient.

3. **Adding a task identifier is one config key per scope.** No code changes needed in resolvers. Only in command handlers if they want to use it.

4. **Adding a prompt template is one file.** No fish code changes; loader pattern handles fallback.

5. **Project config beats global config.** Always. No exceptions. If a user sets something in project, they meant it.

6. **Sessions are ollama-only by design.** This is not a temporary limitation. Bridging claude (parsing its storage, mapping IDs) is rejected as architecturally wrong. See [the sessions boundary](#sessions-a-parallel-pipeline).

7. **No filesystem access from provider plugins.** Plugins know about their tool. Reading files for context delivery is the command handler's responsibility (Layer 4-5). Agent runners are the deliberate exception — reading the repo (read-only) is their whole purpose, and they are only reached via an explicit `--agentic`.

8. **Resolvers are pure.** `_ai_default_provider`, `_ai_default_model`, `_ai_config_read` have no side effects, no caching mutations. Read-only.

9. **Pre-resolve before workdir cd.** Command handlers resolve provider/model from the user's invocation PWD, BEFORE entering any internal `cd`. This ensures project config is taken from where the user invoked, not where the runner walked to.

10. **JSONL append-only.** Once a session row is written, it stays. Operations that "modify" sessions (clear, edit) rewrite the file under the hood, but the runtime expectation is that turns and summaries are append-only.

## Cross-cutting concerns

**Dry-run.** `--dry-run` is implemented at the dispatcher (Layer 3) and forwarded through all command handlers. The dispatcher prints the assembled prompt to stdout, a label to stderr, and returns 0 before invoking the provider. Command handlers detect `--dry-run` to suppress side-effect cues ("Saved to: $file" message when nothing was saved).

**Completions.** `completions/ai.fish` consumes the same discovery mechanisms used at runtime: `_ai_providers` for provider names, `_ai_tasks` for task names, `_ai_session_names` for session names, `_ai_review_lens` (via `_ai_complete_lens`, which handles comma-stacked values) for lenses, and `_ai_complete_models` for models — it reads the installed-models cache (so it works with the server down), falls back to `ollama list` when the cache is cold, and adds the claude aliases for `--verify-model`. So tab-completion is automatically consistent with what the toolkit knows about.

**Stow.** Files in the repo at `fish/.config/fish/functions/`, `prompts/`, `completions/` are symlinked into `~/.config/fish/` by `install.sh` (which wraps `stow`). When new files are added or deleted in the repo, `stow --restow fish` and `find … -type l ! -exec test -e {} \;` should be run to update symlinks and prune broken ones.

**Error surface.** Error messages are user-facing: red `set_color`, prefixed with "Error:", followed by a hint for resolution. Warnings are yellow `set_color`. The pattern is: explain what failed, then say what the user should do.

## Boundaries and what we deliberately don't do

| Concern | Status |
|---|---|
| Bridge to claude CLI sessions | Rejected — each tool owns its territory |
| Direct Anthropic API access | Rejected — API gating, requires separate billing |
| Manage pi / opencode / claude-code state | Rejected — same boundary principle |
| Vector search / embeddings for sessions | Not yet — out of scope for current implementation |
| Cross-provider session migration | Rejected — sessions are scoped to one provider for life |
| Encryption for sessions storage | Not yet — could be added without changing architecture |
| Per-project prompt templates | Not yet — straightforward extension of the walk-up pattern |
| Streaming for `ai gen`/`ai review` | Done — the ollama provider requests `stream:true` and emits chunks via `jq --unbuffered`; file output shows a live line count (`_ai_run_watched`) |
These are architectural decisions, not bugs. They can be revisited if user pain emerges.
