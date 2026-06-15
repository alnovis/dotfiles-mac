# How-to / best practices

> See also: [Architecture](architecture.md) · [Toolkit reference](toolkit.md) · [Sessions](sessions.md)

Real scenarios. Each section answers a single "I want to ..." question with steps and commands. Definitions and design rationale live in the other docs; this one connects them.

## Contents

- [Getting started](#getting-started)
- [Per-task and per-project setup](#per-task-and-per-project-setup)
- [Daily workflows](#daily-workflows)
- [Sessions patterns](#sessions-patterns)
- [Prompt tuning](#prompt-tuning)
- [Troubleshooting and inspection](#troubleshooting-and-inspection)
- [Migration and sync](#migration-and-sync)

## Getting started

### Verify the toolkit works after install

```
ai --help
ai config status
ai models list
```

If `ai --help` errors, fish hasn't picked up the autoloaded functions yet — open a new shell or `source ~/.config/fish/config.fish`.

If `ai models list` shows nothing, Ollama isn't running or isn't installed. Install with `brew install ollama`, then `ollama serve &`. The toolkit will start the daemon automatically when needed.

### Install a starter model

```
ai models install qwen3.5:9b
ai models use qwen3.5:9b
ai chat "say hi"
```

This sets `qwen3.5:9b` as the global default and runs a one-shot test prompt.

### Set Claude as available (optional)

Install Claude Code CLI (web login flow at claude.ai/code). Once `claude` is on `$PATH`, the toolkit picks it up — verify:

```
ai config provider claude
ai "hi" --provider claude
```

If `claude` is not installed, the toolkit warns when you try to set it as a provider.

## Per-task and per-project setup

### Use claude for review, ollama for everything else

```
ai config provider claude --task review
ai config status            # check: review row should show provider: global, model: —
```

Now `ai review` (any mode) uses Claude; `ai gen commit`, `ai chat`, `ai code`, etc. continue with Ollama.

### Smaller, faster model for commit messages

Commit messages are short — a 7B model is plenty.

```
ai models use qwen2.5-coder:7b --task commit
ai gen commit --dry-run     # confirm the prompt looks right
ai gen commit               # generate the real thing
```

### Project-specific override for a single repo

Inside the repo:

```
cd ~/work/scala-project
ai config provider claude --task review --project
ai config provider ollama --task commit --project
ai models use qwen2.5-coder:32b --task code --project
```

Result: a `.ai/config` file at the repo root. Outside this repo, your global config still applies. See [walk-up resolution](architecture.md#layer-3-configuration) for the precedence rules.

### See where each value comes from

```
ai config status
```

The origin column shows `project`, `global`, `env`, or `default` for each task's resolved provider/model. Use this to debug "why is X using Y?"

### Promote a project setting to global

You decided the project's preference should apply everywhere:

```
ai config move --task review --to global
```

This reads the per-task keys from project, writes them to global, removes from project. See [Move (between scopes) in sessions.md](sessions.md#move-between-scopes) for the symmetric concept on sessions.

## Daily workflows

### Quick review of staged changes

```
git diff --staged | ai "review for bugs and missing edge cases"
```

Or via the dedicated command (more structured prompt, severity-tiered output):

```
git add -p src/foo.scala
ai review --file src/foo.scala
```

`--file` filters the branch-vs-base diff to one file.

### Review of the whole branch before pushing

```
ai review                            branch vs auto-detected base
ai review main                       vs specific base
ai review --brief                    short summary instead of detailed
ai review --lang ru                  in Russian
```

### Generate a commit message and pipe to git

```
ai gen commit | git commit -F -
```

Or save to a draft for hand-editing:

```
ai gen commit -o /tmp/msg.txt
$EDITOR /tmp/msg.txt
git commit -F /tmp/msg.txt
```

### One-shot question with a heavier model for one turn

```
ai "explain this code in detail" --model qwen2.5-coder:32b < src/foo.scala
```

The override applies to this call only — your defaults aren't touched.

### Compare what would be sent before paying for the call

```
ai gen commit --dry-run
ai review --last 3 --dry-run
ai review src/Foo.scala --dry-run
```

Especially useful for Claude (don't pay for large prompts you didn't realize were large) or to inspect prompt assembly when iterating templates.

## Sessions patterns

### Continue what I was working on yesterday

```
ai chat -c
```

Reads `.last` (project, then global). If your most-recent session was in a different project, `cd` there first.

### Start a fresh session for a new topic

```
ai chat -s api-design
```

If a session with that name exists, it's resumed. To guarantee fresh, add `--new`:

```
ai chat -s api-design --new
```

Errors with the path if a session already exists under that name.

### Long debug session with model switching

Start with a small model for cheap back-and-forth:

```
ai chat -s debug-foo
> ... discuss the symptom ...
```

When you hit a hard question, switch to a heavier model for one turn:

```
ai chat -s debug-foo --model qwen2.5-coder:32b
> ... ask the hard question ...
```

Note: switching mid-session is per-turn only. To lock the session to a heavier model permanently:

```
ai sessions pin debug-foo --model qwen2.5-coder:32b
```

The pin records to the session file; future runs honor it. See [pinning in sessions.md](sessions.md#pinning).

### Fork before risky exploration

You're in a useful conversation but want to try a different angle without losing the current path:

```
ai sessions branch debug-foo
ai chat -s debug-foo-branch-1
> ... explore the alternative ...
```

If the branch doesn't pan out, `ai sessions rm debug-foo-branch-1` and the original is untouched.

### Archive when done

Keeps the project session listing clean:

```
ai sessions archive debug-foo
```

Restore later with `ai sessions restore debug-foo`. Archived sessions still show up in `ai sessions ls --archived` and in `ai sessions search ... --all`.

### Find a fact across all your sessions

```
ai sessions search "migration plan"
ai sessions search "Marina" --all                    include archived
ai sessions search "Option[String]" --since 2026-05-01
```

Search hits show the session name + scope + matching turns. Open a session to see surrounding context with `ai sessions show NAME`.

### Save a useful session as documentation

```
ai sessions export debug-foo -f md > docs/foo-debug-notes.md
git add docs/foo-debug-notes.md
git commit -m "docs: capture foo debug session"
```

`-f md` renders user/assistant blocks as markdown sections.

### Promote a personal session to be team-visible

By default sessions in `<project>/.ai/sessions/` are typically gitignored. To share intentionally:

```
ai sessions move my-session --to project
# Edit your .gitignore to NOT ignore .ai/sessions/my-session.jsonl
git add .ai/sessions/my-session.jsonl
git commit -m "docs: shared design session for X"
```

## Prompt tuning

### Adjust the commit message prompt

Edit the template:

```
$EDITOR ~/.config/fish/prompts/meta-commit.md
```

Test the change without spending tokens on a model call:

```
ai gen commit --dry-run
```

When happy, run for real:

```
ai gen commit
```

The same pattern applies to `meta-summary.md`, `meta-review.md`, `meta-review-diff.md`, and `meta-session-summary.md`. See [Prompt templates in toolkit.md](toolkit.md#prompt-templates) for the full list.

### One-off custom instruction for a single review

```
ai review . "focus on error handling and missing edge cases"
ai review --last 3 "explain the performance impact"
```

The custom prompt is appended to the loaded template. No need to edit the template file for ad-hoc focus.

### Use a different model for session summarization

Default: same model as the session. Override:

```
echo "sessions_summary_model=qwen2.5:3b" >> ~/.config/ai/config
```

Or per-project:

```
echo "sessions_summary_model=qwen2.5:3b" >> .ai/config
```

A smaller fast model for the summary call cuts wait time when the truncation triggers mid-conversation. Quality tradeoff applies.

## Troubleshooting and inspection

### Find why `ai review` is using claude when global is ollama

```
ai config status
```

Look at the `review` row: origin tells you which layer set the provider. Likely candidates:

- `project` — there's a `.ai/config` in the current directory tree. View it: `cat <project-root>/.ai/config`. Edit or `ai config reset --task review --project` to clear.
- `global+top` — a top-level `provider=` setting in global is inherited. Override per-task: `ai config provider ollama --task review`.

### See what would actually be sent to the model

```
<your-command> --dry-run
```

Prints the assembled prompt (template + context + language preamble + custom suffix) to stdout. Useful for:

- Verifying a prompt template change took effect
- Checking diff size before a large review
- Debugging "why did the model say X" — was it in the prompt?

### Recover from a corrupted session file

If `ai sessions show NAME` errors with a `jq` parse error:

```
$EDITOR ~/.config/ai/sessions/NAME.jsonl
```

Each line should be valid JSON with a `t` field. Common breakage: a multi-line content with unescaped newlines. Either delete the offending lines, or `jq` each line through to revalidate.

If hopeless:

```
ai sessions rm NAME --force
```

For recoverable data, consider [exporting](sessions.md#backup-and-migration) sessions regularly to a backup location.

### See what's in a session without running it

```
ai sessions show NAME              markdown rendered
ai sessions info NAME              meta + stats
cat ~/.config/ai/sessions/NAME.jsonl | jq -c .   raw JSONL
```

### Audit token usage across all sessions

```
ai sessions stats                  active sessions
ai sessions stats --all            include archived
```

Shows total input/output tokens, model breakdown. For per-session detail, `ai sessions info NAME`.

### Clean up broken symlinks after deleting a function

If you removed a `_ai_*.fish` file from the repo, the corresponding symlink in `~/.config/fish/functions/` becomes dangling. Detection and cleanup:

```
find ~/.config/fish/functions/ -maxdepth 1 -type l ! -exec test -e {} \; -print -delete
stow --restow fish
```

Without this, `functions -an` lists the dangling name as a candidate and `_ai_providers` (which uses it) may surface ghosts. The toolkit defensively filters via `functions -q`, but cleaning up is still good hygiene.

### Why is a session truncating earlier than expected?

You see `[ctx_truncated kept=N total=M budget=X]` and feel it's premature. Check the model's context window:

```
ai models info <your-model>
cat ~/.cache/ai-context-windows.json
```

Then raise the threshold:

```
echo "sessions_token_threshold=0.85" >> ~/.config/ai/config
```

Default is `0.7` (truncate at 70% of context window). Higher = wait longer before truncating, but risk hitting the model's hard limit.

## Migration and sync

### Sync sessions to another machine

```
rsync -av ~/.config/ai/sessions/ other-machine:~/.config/ai/sessions/
```

For project-scoped sessions, sync the project tree as usual (rsync, syncthing, git). No special handling — sessions are plain files in known locations.

### Export everything for a backup

```
mkdir -p ~/backup/ai-$(date +%Y%m%d)
cp -r ~/.config/ai ~/backup/ai-$(date +%Y%m%d)/global
# For each project with sessions:
for proj in ~/work/*/; do
  test -d "$proj/.ai" && cp -r "$proj/.ai" ~/backup/ai-$(date +%Y%m%d)/"$(basename $proj)"
done
```

Restore by copying back into place.

### Import sessions from an old machine

```
ai sessions import ~/old-machine-backup/NAME.jsonl --name imported-name
```

The first line must be a `meta` record (it will be in any file produced by this toolkit).

### Bulk export sessions as markdown

```
mkdir -p ~/notes/sessions
for s in (fish -c '_ai_session_names')
  ai sessions export $s -f md > ~/notes/sessions/$s.md
end
```

Useful when migrating to a different tool or for one-off review.

### Track sessions in git for a project

Decide which sessions are team-shared. For shared:

```
ai sessions move shared-design-discussion --to project
# Add to git
git add .ai/sessions/shared-design-discussion.jsonl
git commit -m "docs: add design discussion as session"
```

For personal sessions in a shared repo, add `.ai/sessions/` to `.gitignore` and only un-ignore specific files you intend to share.
