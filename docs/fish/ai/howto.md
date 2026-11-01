# How-to / best practices

> See also: [Architecture](architecture.md) · [Toolkit reference](toolkit.md)

Real scenarios. Each section answers one "I want to …" question with steps and commands.
Definitions and rationale live in the other docs; this one connects them.

## Contents

- [First run](#first-run)
- [Pick models per task and per project](#pick-models-per-task-and-per-project)
- [Try a new model](#try-a-new-model)
- [Review workflows](#review-workflows)
- [Use a cloud provider through the runner](#use-a-cloud-provider-through-the-runner)
- [Off-network: fallback to local](#off-network-fallback-to-local)
- [Interactive: `ai code` and `ai chat`](#interactive-ai-code-and-ai-chat)
- [Everyday generation](#everyday-generation)
- [Prompt tuning](#prompt-tuning)
- [Troubleshooting and inspection](#troubleshooting-and-inspection)

## First run

### Install and check

```
./install.sh               # brew bundle, stow fish + agents (skills, opencode profiles)
ai --help
ai providers               # which executor serves which provider
ai config status           # resolved provider/model per task
```

If `ai --help` fails, fish hasn't seen the new functions yet: open a new shell.

### Set a default model

A fresh machine has no default model, and `ai` won't guess one:

```
$ ai "say hi"
ollama: no model configured — set one with: ai models use MODEL
```

Install one and make it the default:

```
ai models info qwen3.5:9b      # size, RAM fit, capabilities, before downloading
ai models install qwen3.5:9b
ai models use qwen3.5:9b       # writes model=qwen3.5:9b to ~/.config/ai/config
ai "say hi"
```

The ollama server is started on demand. `ai chat` takes a model name as its positional, not a
prompt; for a one-shot question use `ai "…"`.

### Make claude available (optional)

Log in to the Claude Code CLI (installed by the Brewfile). Then:

```
ai providers check claude
ai --provider claude "hi"
```

`--provider claude` always runs the claude CLI; no API key goes through `ai`.

### Install a runner (for `--agentic`, `ai code`, `ai chat`, cloud providers)

The Brewfile installs ollama, pi, opencode and the claude CLI. pi is the default runner; for
opencode add `agent=opencode` to `~/.config/ai/config` (or a project `.ai/config`). For ollama via
the runner,
register your models in the runner's config — see
[Agentic runs on ollama come back empty](#agentic-runs-on-ollama-come-back-empty).

## Pick models per task and per project

### One model per task

```
ai models use commit qwen2.5-coder:7b          short messages: a small model is plenty
ai models use review,verify qwen3:30b          two tasks at once
ai models use code devstral-small-2:24b
ai config status                               check the result and where each value comes from
```

`ai models use MODEL` (no task) sets the default model and must name an installed model;
per-task values are trusted as-is.

### Claude for review, local for everything else

```
ai config provider claude --task review
ai config status            # review row: provider global, model — (claude's default)
```

A per-task model follows the task's configured provider. If `review_model` was an ollama tag,
it is now handed to claude. Fix it one of two ways:

```
ai models use review sonnet                    a claude model for the review task
# or
ai config reset --task review                  drop review_provider AND review_model …
ai config provider claude --task review        … then set the provider again
```

### Generate locally, verify with claude — permanently

```
ai config provider ollama --task review
ai config provider claude --task verify
ai models use review qwen3:30b
```

Then `ai review --verify` splits the work without flags. To make `--verify` the default (opt out
with `--no-verify`), add a line by hand to `~/.config/ai/config` or a project `.ai/config`:

```
review_verify=1
```

### Project-specific overrides

```
cd ~/work/scala-project
ai config provider claude --task review --project
ai models use code qwen2.5-coder:32b --project
ai models use qwen3.5:27b --project            a project-wide default model
```

This writes `<git-root>/.ai/config`. Outside the repo the global config applies. Promote a
project setting later with `ai config move --task review --to global`.

### Why is X using Y?

```
ai config status
```

Origins: provider `project` / `global` (a per-task key), `project+top` / `global+top` (that
layer's top-level `provider=`), `default`; model `project`, `global`, `env`
(`AI_DEFAULT_MODEL` — a one-off override that beats the `model` key), or `—` (not set).

## Try a new model

```
ai models search qwen                  opens ollama.com search in the browser
ai models info qwen3:30b               download size, RAM fit, params, quant, vision — no download
ai models try qwen3:30b                info, confirm, pull, mark as a trial
ai models use review qwen3:30b         put it to work
ai review --last 3                     …try it on real changes
ai models keep qwen3:30b               a keeper: clear the trial mark
ai models drop qwen3:30b               or: remove every tag of it, and its metadata
```

`ai models` shows trials with their age (`trial, 3d`), so forgotten experiments are easy to spot.
`drop` warns if the model is still configured for a task or as the default.

Group the keepers by purpose:

```
ai models label qwen3:30b coding
ai models                              Coding group first, then General
```

Check `Needs ollama:` in `ai models info` before trying a new model family: if it says `NEWER
than your …`, update ollama first.

## Review workflows

### Review uncommitted work

`ai review` reviews committed history only. For staged changes:

```
git diff --staged | ai "review for bugs and missing edge cases"
```

For the structured, severity-tiered review, commit first and review that commit:

```
git commit -m wip
ai review --last
git reset --soft HEAD~1                un-commit, keep the changes staged
```

### Review a branch before pushing

```
ai review                              branch vs develop / main / master
ai review main                         vs a specific base
ai review --brief                      3–5 bullets instead of the full review
ai review --lang ru                    in Russian
```

### Add a lens

```
ai review --lens access-control                 authorization checklist on the diff
ai review . --lens crypto,logic-bug             two lenses on the whole project
ai review --lens rust-async,rust-ownership      a tokio change
ai review k8s/ --lens k8s-manifest              deployment YAML
ai review --lens sql-postgres                   a migration commit
```

Pick by what the change touches: security (`access-control`, `crypto`, `deserialization`,
`logic-bug`, `injection`, `ssrf`, `sensitive-data`), quality (`error-handling`, `resource-leak`, `reactive`, `documentation`,
`k8s-manifest`), Rust (`rust-unsafe`, `rust-async`, `rust-ownership`), shell (`bash`, `fish`), data (`sql-postgres`,
`sql-clickhouse`, `hbase`, `redis` — one engine each). `--lens crypto,<Tab>` stacks. Full table:
[toolkit.md](toolkit.md#lenses---lens).

### Second-opinion verify

```
ai review --verify                                  review, then try to refute each finding
ai review --provider ollama --verify --verify-provider claude
ai review --verify -o review.md                     review.md + review.verify.md
```

With `-o`, the review is saved as soon as pass 1 ends; the verdicts go to a separate file. A
default verify pass reasons from the code the review saw (the diff, or the file); add `--agentic`
to let the verifier read the repo itself.

### Re-verify a review you already paid for

```
ai review --provider claude -o review.md                         the costly review, once
git diff main...HEAD > /tmp/change.diff
ai review --verify-only review.md --verify-provider ollama --verify-model qwen3:30b \
    --file /tmp/change.diff                                      local verifier, grounded in the diff
ai review --verify-only review.md --agentic -o second-opinion.md the verifier reads the repo
```

`--file` must be a regular file. Run it from the repo root when you use `--agentic`.

### Let the model explore (`--agentic`)

A default review embeds everything up front: diff + full changed files, or file + tree +
README. With `--agentic` only the minimum is embedded and the model reads what it needs:

```
ai review --agentic                              branch diff; the model opens what it needs
ai review --last 3 --agentic --verify -o r.md    agentic review + agentic verify
ai review src/Auth.scala --agentic --provider claude
```

Who explores: claude with `Read`/`Grep`/`Glob`; any other provider, ollama included, through the
runner (pi by default). The `ai-review` / `ai-verify` skill is injected. Check before paying:

```
$ ai review --last 1 --agentic --dry-run
...
--- dry-run: prompt that would be sent to ollama via pi (profile read), skill ai-review ---
```

Useful when the change is small but its callers matter, or when the changed files are too big to
embed.

### Faster pass with a thinking model

```
ai review --no-think
ai review --no-think --verify          both passes
```

No reasoning, no sidecar; native ollama only. Without `--no-think`, a review written with `-o`
keeps the model's reasoning next to it as `review.thinking.md`.

### Large commits

The diff is capped at 500 lines; full changed files are embedded up to 2000 lines:

```
git diff HEAD~1..HEAD | wc -l                                 check the real size
ai review --last 1 --max-lines 4000 --provider claude -o review.md
ai review --context-lines 6000                                embed big files
ai review --context-lines 0                                   diff-only: smallest prompt
```

If the native driver says `over the 131072 ceiling`, drop to `--context-lines 0`, use
`--agentic`, or raise `ollama_max_ctx` if you have the RAM.

### Use the skills by hand

The same procedure is available inside an agent session, without `ai`:

```
/ai-review --last 2 --lens crypto          in claude
/ai-verify review.md --file change.diff    in claude
/skill:ai-review main                      in pi
```

The model picks the diff itself with git and reads the rules and lenses from the skill's
`references/`. An unknown lens name is reported with the list of available ones.

## Use a cloud provider through the runner

`ai` keeps no provider list: a provider exists when the runner knows it. Example with an
OpenAI-compatible gateway (here called `litellm`) in pi.

### 1. Configure it in the runner

`~/.pi/agent/models.json` (illustrative; see pi's docs for the full schema):

```json
{
  "providers": {
    "litellm": {
      "baseUrl": "http://gateway.example/v1",
      "api": "openai-completions",
      "apiKey": "<key>",
      "models": [{ "id": "<model-id>", "contextWindow": 131072 }]
    }
  }
}
```

The reachability probe reads `baseUrl` from this file. For opencode the provider goes into
`~/.config/opencode/config.json` under `provider.litellm` (the probe reads
`provider.litellm.options.baseURL`), and the config needs `agent=opencode`.

### 2. Check it

```
ai providers                     a "litellm  via pi" row should appear
ai models --provider litellm     the models pi has for it
ai providers check litellm       expect: litellm: reachable (via pi)
```

### 3. Use it

```
ai --provider litellm "explain this" < src/foo.rs     single-shot via pi, no tools
ai review --provider litellm --model <model-id>
ai config provider litellm --task review              make it the review default
ai models use review <model-id>                       optional: without it, pi's first model for litellm
ai code --provider litellm                            interactive, via pi
```

A provider the runner doesn't know fails at once:
`Provider nosuch: unknown to runner pi — configure it in pi, or pick another provider (ai providers)`.

## Off-network: fallback to local

Before a runner run, `ai` checks the provider URL (at most 2 s). When it doesn't answer and you
are at a terminal:

```
litellm unreachable (via pi) — off-network? Run on ollama/<model> instead? [y/N or a model name]
```

- `y` → the default ollama model; type a model name to pick another; Enter → abort.
- The run continues on ollama and says so on stderr:
  `↳ running on ollama/<model> (ollama (native), fallback from litellm)`.
- `--agentic` runs fall back to the runner's ollama, not the native driver.

Without a terminal (scripts, `-o` from a job), or with `AI_NONINTERACTIVE=1`, there is no
question, just the error and exit 1:

```
litellm unreachable (via pi) — off-network? Rerun with --provider ollama
```

Ask up front with `ai providers check litellm`, or skip the cloud for one run with
`--provider ollama`. `ai code` and `ai chat` are not probed.

## Interactive: `ai code` and `ai chat`

```
ai code @src/main.rs               code task's provider; no file edits (pi still prompts for bash)
ai code -e                         allow edits
ai code --provider claude          the claude CLI
ai code --dry-run                  which executor and model would start
```

```
ai chat                            chat task's provider, via the runner (keeps history)
ai chat -c                         continue the last chat
ai chat -r                         pick one to resume
ai chat qwen3.5:27b                another model for this chat
ai chat --provider claude -c       continue the last claude conversation
```

History lives in the runner (pi / opencode) or the claude CLI, never in `ai`. For a throwaway
`ollama run` with no history, run `ai` with no arguments (with ollama as the top-level provider).
`--dry-run` shows the plan:

```
would start: ollama via pi (profile none), interactive, continue last, model default-model
```

## Everyday generation

### Commit messages

```
ai gen commit | git commit -F -
ai gen commit -o /tmp/msg.txt && $EDITOR /tmp/msg.txt && git commit -F /tmp/msg.txt
```

Uses staged changes, else unstaged.

### A heavier model for one question

```
ai "explain this in detail" --model qwen2.5-coder:32b < src/foo.scala
```

The override applies to this call only.

### See what would be sent before paying

```
ai gen commit --dry-run
ai review --last 3 --dry-run
ai review src/Foo.scala --provider claude --dry-run
```

The header names the executor (`ollama (native)`, `claude (runner claude, profile none)`,
`litellm via pi (profile read), skill ai-review`); the prompt is on stdout.

## Prompt tuning

```
$EDITOR ~/.config/fish/prompts/meta-commit.md
ai gen commit --dry-run            check the change without a model call
```

The same works for `meta-summary.md`, `meta-review.md`, `meta-review-diff.md`, `meta-verify.md`
and `lenses/*.md`. A new `lenses/<name>.md` is a selectable lens at once, in the CLI and the
`ai-review` skill. Templates are read fresh on every run.

For one-off focus, append an instruction instead of editing a template:

```
ai review . "focus on error handling and missing edge cases"
ai review --last 3 "explain the performance impact"
```

After changing the toolkit itself, run the harness:

```
tests/ai/run.fish                  goldens + smoke, offline, about a second
tests/ai/run.fish --update         rewrite goldens after an intended change (review the diff)
```

## Troubleshooting and inspection

### Which executor, which model?

```
ai config status                   resolved provider/model per task, with origins
ai providers                       executors and model counts
ai <command> --dry-run             executor label + exact prompt
```

### Agentic runs on ollama come back empty

Runners (pi, opencode) talk to ollama through its OpenAI-compatible endpoint, which uses the
server's `OLLAMA_CONTEXT_LENGTH` (131072 in `conf.d/env.fish`) instead of a per-request size. A
big prompt plus file reads can overflow the window and come back empty. Register every ollama
model you use through the runner, with a context window that matches the server's, e.g. in
`~/.pi/agent/models.json` under `providers.ollama.models`:

```json
{ "id": "qwen3:30b", "contextWindow": 131072 }
```

If prompts still don't fit, raise `OLLAMA_CONTEXT_LENGTH` (more KV-cache RAM) and restart the
server, or review a smaller range.

### The cloud provider "hangs"

It shouldn't any more: an unreachable provider is caught by the probe in about 2 s. If a run
still waits a long time, the endpoint answers but the model is slow or the key is wrong — run
the runner directly (`pi -p --model litellm/<model-id> "hi"`) to see its own error.

### claude quotes my notes in a review

`claude -p` loads your Claude Code memory and the project's `CLAUDE.md`, and they can leak into
a review. Keep that in mind when reviewing with claude in a repo that has them.

### A model is missing from completion or `ai models`

`ai models` and model completion read `~/.cache/ai-models.json`, refreshed whenever `ai models`
reaches the server. Run `ai models` once with ollama up. Completion is cached per fish session:
`exec fish` after changes.

### Clean up after deleting functions

```
find ~/.config/fish/functions/ -maxdepth 1 -type l ! -exec test -e {} \; -print -delete
stow --restow fish
```

### Leftovers from the old toolkit

Safe to delete if present: `~/.cache/ai-registry.json` (old catalog cache, no longer read) and
`~/.config/ai/model-labels` (labels now live in `~/.config/ai/models.json`).
