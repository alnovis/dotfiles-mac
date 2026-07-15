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
| `-t`, `--think` | Enable thinking mode (ollama models that support it) |
| `--provider PROV` | Override resolved provider (ollama, claude) |
| `--dry-run` | Print assembled prompt to stdout, label to stderr, return 0 without invoking |

### `ai chat`

Interactive chat with the default chat model. Stateless by default — each invocation is a fresh conversation.

```
ai chat                              start REPL with task=chat resolved model
ai chat qwen2.5-coder:32b            override model (positional)
```

**Flags:**

| Flag | Effect |
|---|---|
| `-s`, `--session NAME` | Start or resume named session (see [Sessions](#sessions)) |
| `-c`, `--continue` | Resume the last session (read from `.last` pointer) |
| `--new` | When combined with `--session`, error if session already exists |
| `--global` | When creating a new session, force global scope |
| `--system "..."` | System prompt (only applied at session creation) |
| `--model MODEL` | Override model for this run |
| `--provider PROV` | Override provider (sessions require ollama) |

`--session` and `-c` activate the session pipeline. `--provider claude` with a session is blocked with an error suggesting `claude --resume` / `claude -c`.

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

- **Git mode** — review changes (diff vs base, last N commits, specific commit, file filter)
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
| `--lang-all LANG` | Force language for response AND thinking (slower) |
| (any other) | See [Common flags](#common-flags) |

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

Diff size cap: 500 lines by default — larger diffs are truncated with a warning. Use `--file` to scope down.

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

- `--last`, `--commit`, `--file` require git mode → error if combined with a PATH target.
- `--with-project-context` requires target mode → error if used without a PATH.

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
| `ai sessions search QUERY [--name PAT] [--since DATE]` | Search across messages |
| `ai sessions stats [--all]` | Aggregated counts + tokens |
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
| `ai sessions pin NAME --provider P --model M` | Lock provider/model for this session |
| `ai sessions unpin NAME` | Remove pin |

A pinned session uses the pinned model/provider regardless of task-level config or `AI_DEFAULT_MODEL`. Override per-turn with explicit `--model`.

## Configuration

`ai config` manages provider and model defaults at three layers: global, project, and per-task. See [architecture.md](architecture.md#layer-3-configuration) for the resolver chain.

### View

```
ai config                            show project + global sections side-by-side
ai config status                     resolved per-task with origin annotations
ai config provider                   show resolved global provider
ai config provider --task review     show resolved provider for one task
ai config tasks                      list known task identifiers
```

`ai config status` output includes per-task resolved values with origin tags (`project`, `global`, `env`, `default`). Use it to answer "why is `ai review` using claude?"

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

- **Active selection** header at the top: shows what `ai chat`, `ai code`, etc. would resolve to right now.
- **Used for** column: tags models that are explicitly bound to a task (e.g. `commit`, `default`).

### Install / use / remove

```
ai models install qwen3.5:9b                          pull from ollama.com
ai models rm codellama:13b                            remove
ai models use qwen3.5:9b                              set as global default (sets AI_DEFAULT_MODEL)
ai models use qwen2.5-coder:32b --task code           per-task default
ai models use qwen2.5-coder:7b --task commit --project   per-task project-scoped default
```

| Flag | Effect |
|---|---|
| `--task X` | Set for one task (or comma-list, or `all`) |
| `--project` | Write to project config (requires `--task`) |

`ai models use MODEL` without `--task` sets the legacy `AI_DEFAULT_MODEL` universal variable. The model must be installed for global `use`; per-task writes are not validated (you may set a claude-side model name when the task uses claude).

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
| `-l`, `--lang LANG` | gen, review | Response language code (`en`, `ru`, `de`, etc.) |
| `-o`, `--output FILE` | gen, review | Save output to file |
| `--dry-run` | gen, review, chat | Print assembled prompt without invoking |
| `--task X` | config, models use | Scope to one or more tasks |
| `--project` | config, models use, sessions move | Operate on project layer |
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
| `meta-session-summary.md` | Rolling summary in long sessions |

Iterate freely — changes take effect on the next invocation. No fish reload needed (templates are read fresh each time).

## Files and paths

| Path | What |
|---|---|
| `~/.config/ai/config` | Global config (`provider`, `<task>_provider`, `<task>_model`, sessions params) |
| `<project>/.ai/config` | Per-project config (walk-up from PWD; see [architecture.md](architecture.md#layer-3-configuration)) |
| `~/.config/ai/sessions/<name>.jsonl` | Global session storage |
| `<project>/.ai/sessions/<name>.jsonl` | Project session storage |
| `~/.config/ai/sessions/.last` | Pointer to most recent global session |
| `<project>/.ai/sessions/.last` | Pointer to most recent project session |
| `~/.config/fish/prompts/meta-*.md` | Prompt templates (symlinked from dotfiles) |
| `~/.cache/ai-models.json` | Local installed-models cache |
| `~/.cache/ai-registry.json` | Ollama catalog cache |
| `~/.cache/ai-context-windows.json` | Per-model context-window cache (sessions) |

## Environment variables

| Variable | Read by | Effect |
|---|---|---|
| `AI_DEFAULT_MODEL` | resolver chain | Legacy global model default (universal var, settable via `ai models use MODEL`) |
| `OLLAMA_CONTEXT_LENGTH` | Ollama itself | Raises Ollama's default 4K context to a higher value (set globally in `env.fish`) |
| `EDITOR` / `VISUAL` | `ai sessions edit` | Editor for raw JSONL editing |
| `ANTHROPIC_API_KEY` | Not used by this toolkit | Claude CLI manages its own auth via web login |

## Tab-completion

`completions/ai.fish` provides context-sensitive completions:

- Top-level subcommands
- Subcommands of `gen`, `models`, `config`, `sessions`
- Flag names per subcommand
- Provider names (from `_ai_providers` — auto-discovers all installed providers)
- Task names (`chat`, `code`, `review`, `commit`, `summary`)
- Session names for `ai sessions show/info/rm/...` and `ai chat -s ...`
- Installed Ollama models for `ai models use/rm/info`, `--model` flag
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

**`Ollama is not running`** but actually it is

`_ai_ensure_running` checks via `pgrep ollama`. If Ollama is running under a different process name (rare), this check fails. Manually run `ollama serve &` to start.

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
