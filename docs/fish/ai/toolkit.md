# AI toolkit reference

> See also: [Architecture](architecture.md) · [How-to](howto.md)

Command reference for `ai`. For the design behind these commands (executors, runner contract,
context policy), see [architecture.md](architecture.md).

## Contents

- [Quick reference](#quick-reference)
- [Top-level `ai`](#top-level-ai)
- [`ai chat`](#ai-chat)
- [`ai code`](#ai-code)
- [`ai review`](#ai-review)
- [`ai gen`](#ai-gen)
- [`ai providers`](#ai-providers)
- [`ai models`](#ai-models)
- [`ai config`](#ai-config)
- [`ai stop`](#ai-stop)
- [Config keys](#config-keys)
- [Environment variables](#environment-variables)
- [Prompt templates](#prompt-templates)
- [Files and paths](#files-and-paths)
- [Tab-completion](#tab-completion)
- [Troubleshooting](#troubleshooting)

## Quick reference

```
ai [PROMPT]                          one-shot prompt; interactive with no prompt
ai chat [MODEL] [-c | -r]            interactive chat, history kept by the runner / claude CLI
ai code [-e] [ARGS...]               interactive coding session (no file edits unless -e)
ai review [PATH | BASE | --last N]   code review, mode auto-detected
ai review --verify-only FILE         re-verify a saved review (no review pass)
ai gen commit                        commit message from staged (else unstaged) changes
ai gen summary [DIR]                 project summary
ai providers [ls | check NAME]       providers, their executors, reachability
ai models [COMMAND]                  installed models, info, try/keep/drop, use, label, …
ai config [SUBCOMMAND]               provider config, resolved per-task status
ai stop [MODEL | --server]           stop running ollama models or the server
ai --help                            top-level help
```

Every command takes `-h` / `--help`.

**Executors in one line:** `ollama` single-shot → the native ollama driver; `claude` → the claude
CLI; a single call to a provider the runner reaches over the OpenAI API (litellm, …) → the native
OpenAI driver, with the endpoint read from the runner's config; anything with tools or chat
history, and other providers → the runner named by the config key `agent` (`pi` by default, or
`opencode`). Details: [architecture.md](architecture.md#executor-selection).

## Top-level `ai`

```
ai "explain monads"                  one-shot
git diff | ai "review this"          piped stdin is appended to the prompt
ai                                   interactive (terminal only)
ai --provider claude "question"      one-shot on claude
```

Interactive iff stdin is a terminal, there is no prompt, and no output file. The top-level command
has no task: provider = `--provider` > config key `provider` > `ollama`; model = `--model` > the
default model.

| Executor | Interactive | One-shot |
|---|---|---|
| ollama | `ollama run --think=false MODEL` (no history) | native driver |
| claude | claude REPL | `claude -p`, no tools |
| other | runner TUI, no tools | runner, no tools |

**Flags** (from `ai --help`):

| Flag | Effect |
|---|---|
| `-m`, `--model MODEL` | Use a specific model |
| `-t`, `--think` | Native ollama only. Interactive: `ollama run --think=true`. One-shot: a thinking model reasons anyway (kept out of the answer); a non-thinking model prints `ollama: <model> does not support thinking — ignoring --think` |
| `--provider PROVIDER` | Override provider (ollama, claude, or one the runner knows) |
| `--dry-run` | Print the assembled prompt (stdout) and the executor label (stderr) without invoking the model |

The dispatcher also accepts these (not listed in `ai --help`):

| Flag | Effect |
|---|---|
| `--agentic` | Profile `read`: the executor may read the current directory |
| `--no-think` | Native ollama: send `think:false` even to a thinking model |
| `--output FILE` | Write the answer to FILE (native ollama also writes a reasoning sidecar) |
| `--workdir DIR` | Run in DIR |
| `--skill NAME` | Inject the installed skill NAME into a runner or claude |

Dry-run headers name the executor:

```
$ ai --dry-run hello
--- dry-run: prompt that would be sent to ollama (native) ---
hello

$ ai --provider claude --dry-run hello
--- dry-run: prompt that would be sent to claude (runner claude, profile none) ---
hello
```

## `ai chat`

```
Usage: ai chat [MODEL] [--provider P] [-c | -r] [--dry-run]
```

Interactive chat with the `chat` task's provider and model (`chat_provider` / `chat_model`).
claude → the claude CLI; **every other provider, ollama included → the runner**, which keeps the
chat history. For a bare `ollama run` with no history, run `ai` with no arguments (when the
top-level provider is ollama).

| Flag | Effect |
|---|---|
| `MODEL`, `--model M` | Override the model (the positional wins if both are given) |
| `--provider P` | Override the provider |
| `-c`, `--continue` | Continue the last chat (the runner's / claude's history) |
| `-r`, `--resume` | Pick a past chat to resume |
| `--dry-run` | Show which executor would start, then exit |

The positional is a **model name**, not a prompt; for a one-shot prompt use `ai "…"`. Real
`--dry-run` output (test sandbox, pi as runner):

```
$ ai chat --dry-run
would start: ollama via pi (profile none), interactive, model default-model
$ ai chat -c --dry-run
would start: ollama via pi (profile none), interactive, continue last, model default-model
$ ai chat -r --provider claude --dry-run
would start: claude (runner claude, profile none), interactive, resume (pick), model (executor default)
```

With opencode as the runner, `-r` has no effect (its TUI takes only `--continue`) and the model is
picked in the TUI. The TUI can't restrict tools either, so the runner refuses any profile below
`edit` — `ai chat` (profile none) and `ai code` without `-e` fail with a hint; use `agent=pi`.

## `ai code`

```
Usage: ai code [OPTIONS] [ARGS...]
```

Interactive coding session in the current repository with the `code` task's provider
(`code_provider` / `code_model`): claude → the claude CLI, any other provider → the runner.
Default profile `read`: no file edits (pi also keeps bash and prompts for each command). `-e`
allows edits. Not a sandbox: bash can still touch files.

| Flag | Effect |
|---|---|
| `-e`, `--edit` | Allow file edits (profile `edit`) |
| `--provider P` | Override the provider |
| `--model M` | Override the model |
| `--dry-run` | Show which executor would start, then exit |
| any other argument | Passed to the executor untouched (e.g. pi's `@files`); the claude runner ignores them |

```
ai code @src/main.rs                 analyze, no file edits
ai code -e @src/main.rs              edit mode
ai code --provider claude            coding session in the claude CLI
```

Real `--dry-run` output (test sandbox):

```
$ ai code --dry-run @src
would start: ollama via pi (profile read), interactive, model default-model
  passing: @src
$ ai code -e --dry-run
would start: ollama via pi (profile edit), interactive, model default-model
$ ai code --provider testcloud --dry-run
would start: testcloud via pi (profile read), interactive, model cloud-model
```

With an ollama provider the model must be one the runner knows how to serve well: register it in
pi's `models.json` with a context window matching the server's (see [howto](howto.md#agentic-runs-on-ollama-come-back-empty)).

## `ai review`

```
Usage: ai review [OPTIONS] [TARGET|BASE] ["custom prompt"]
```

One command, two modes, picked from the first positional:

- **Target mode** — the positional exists on disk (file or directory): review its current state.
- **Git mode** — no path, or a git ref: review committed changes. The index and working tree are
  never read; for uncommitted work use `git diff --staged | ai "review this"`.

```
ai review                            git: branch vs auto-detected base
ai review main                       git: vs main
ai review --last 3                   git: last 3 commits
ai review src/Foo.scala              target: one file
ai review .                          target: current project
```

### Common options

| Flag | Effect |
|---|---|
| `--provider P` | Override provider (ollama, claude, or one the runner knows) |
| `--model MODEL` | Override model |
| `--lang LANG` | Response language (default `en`). Long form only: `-l` is not accepted |
| `-o`, `--output FILE` | Save output to file (shows a live progress line instead of streaming) |
| `--brief` | Short 3–5 bullet summary; `--lens` and `--verify` are ignored with a note |
| `--lens NAME[,NAME...]` | Add specialist checklist(s) — see [Lenses](#lenses---lens) |
| `--agentic` | Embed only the diff / target file and let the model explore the repo read-only (claude via its CLI, other providers via the runner). Default: everything embedded, no tools |
| `--no-think` | Fast pass: disable a thinking model's reasoning (native ollama) |
| `--context-lines N` | Line budget for embedding whole files: the changed files in git mode (config key `context_lines`, default 2000), a directory's files in target mode (`dir_context_lines`, default 10000). `0` = none. Precedence: flag > config key (project → global) > default |
| `--dry-run` | Print the assembled prompt without invoking the model |
| `-h`, `--help` | Show help |

### Git mode

| Flag | Effect |
|---|---|
| `--last [N]` | Review the last N commits (default 1). `--last 3` and `--last=3` both work |
| `--commit SPEC` | One commit (`SHA`), a range (`A..B`: after A up to B) or a task's commits (`SHA1,SHA2,…`, any order). Checked to be one change, see below |
| `--file FILE` | Filter the diff to one file |
| `--max-lines N` | Cap the diff at N lines (default 500; larger diffs are truncated with a warning) |
| `--lang-all LANG` | Full response and thinking in LANG (slower) |

- Base auto-detection: `develop` → `main` → `master`; the merge base is taken against
  `origin/<base>` when it exists, else the local branch. On the base branch itself:
  `Already on <base> — use --last or --commit to review`.
- A diffstat of the range is always printed to stderr first.
- **`--commit` ranges are checked before anything runs**, because a diff with someone else's
  changes inside reviews the wrong thing. `A..B` must have A as an ancestor of B and no merge
  inside. A list must be one unbroken line: each commit the direct, single-parent child of the
  previous one. A broken list names what sits in the gaps and prints the pieces as commands:

  ```
  Error: the range is broken — other commits sit between the listed ones:
    between bf17453 and d20bbff:
      f28ab8e Merge branch 'feature/…' into 'release'
      60488f0 … (another task's commit)
  Review the pieces separately:
    ai review --commit 4b31811~1..bf17453
    ai review --commit d20bbff~1..64bd9e5
  ```

  The header lists the commits under review. File contents for the context come from the last
  commit (`git show TIP:path`), so an old range needs no checkout — except with `--agentic`,
  where the agent reads the working tree.
- **Full changed files.** Besides the diff, the complete content of every changed file (as of the
  reviewed tip; deleted and binary files skipped) is embedded when the total fits the
  `--context-lines` budget, reported as `Context window: N lines across M files (budget B)`. Over
  budget: on a terminal you are asked `[1] diff-only (default) [2] embed all`; otherwise diff-only
  with a note. Skipped with `--brief` and `--agentic`.

### Target mode

| Flag | Effect |
|---|---|
| `--with-project-context` | For a file target, also embed the parent directory's tree and README, and relax the "review only this file" note |

What is embedded, for every executor alike:

| Target | Default | `--agentic` |
|---|---|---|
| file | scope note + file content (+ tree + README with `--with-project-context`) | scope note + file content |
| directory | `tree -L 4` (build/VCS dirs excluded) + README (first 100 lines) + every file's content within the `--context-lines` budget | the directory path only |

- **A directory's files.** The files are `git ls-files` of the directory (a `find` that prunes
  build dirs outside a repo); binary and empty files skipped. Reported as
  `Files: N lines across M files (budget B)`. Over budget: on a terminal you are asked
  `[1] tree only (default) [2] embed all`; otherwise tree only with a note naming the flag and
  the config key. Skipped with `--brief` and `--agentic`.
- The same files block is the verify pass's code, so verify checks a directory review against
  the code it saw.

The working directory is the file's parent, or the directory itself.

### Mode-incompatible flags

- `--last`, `--commit`, `--file`, `--max-lines` with a path target →
  `Error: --<flag> is git-mode only and cannot combine with a path target`.
- `--with-project-context` without a path → `Error: --with-project-context is target-mode only (needs a file path)`.
- `--verify-only FILE` short-circuits both modes.

### Prompt depth: full or lean

`meta-review*.md` mark two rules as `<!-- full-only -->`: the ABSENCE gate ("name where you looked
for the control") and the sibling sweep ("check the rest of the diff for the same pattern, then ask
what else is wrong at that site"). Both come from VVAH and suit Claude. Other models turn each
into another round of second-guessing. On a real two-commit work change, qwen3.6 did worse with
them wherever it ran:

| qwen3.6-35b-a3b | full | lean |
|---|---|---|
| local (native ollama) | 139 s, 34 KB thinking, the race talked away as safe | 78 s, 16 KB, the race found |
| cloud (litellm) | 27 s, the race over-graded to Critical, two false Important | 23 s, the race found as Important, no false findings |

So it is the model, not where it runs: `auto` gives **full to claude only, lean to everything
else**. Config key `review_prompt` (`auto` by default, `full`, `lean`; project → global) overrides
it, for example `review_prompt=full` for another model that handles the extra rules. `ai config
status` shows the result and why. The `ai-review` skill reads the templates as they are, so its
agentic runs keep the full rules.

### Lenses (`--lens`)

A lens injects a specialist checklist after the base review prompt. It says *where to look*; the
finding gate and severity rules of `meta-review*.md` still apply. Lenses stack
(`--lens crypto,logic-bug`) and work in both modes. 27 ship today:

| Group | Lens | Hunts for |
|---|---|---|
| Security (adapted from Visa's VVAH) | `crypto` | JWT alg confusion, nonce/IV reuse, non-constant-time compares, weak randomness, TLS verification off, hardcoded keys |
| | `access-control` | IDOR/BOLA, missing authorization checks, privilege escalation, mass assignment, tenant leakage |
| | `logic-bug` | TOCTOU, concurrency on half-initialized state, overflow/narrowing, state-machine confusion |
| | `deserialization` | Untrusted-input deserialization leading to RCE (JVM: `ObjectInputStream`, Jackson default typing, SnakeYAML, …) |
| | `injection` | SQL/shell built from input, XXE, path traversal / Zip-Slip, CRLF and log forging, ReDoS |
| | `ssrf` | Outbound fetches with a caller-controlled URL; redirects, DNS rebinding, deny-list bypasses |
| | `sensitive-data` | Secrets and PII in logs (incl. `toString` of DTOs), stack traces to clients, weak password storage, exposed actuator routes |
| Quality | `documentation` | Docs, comments and examples that drift from the code |
| | `reactive` | Blocking a non-blocking pipeline, lost signals, unbounded buffers (Reactor, reactive Kafka) |
| | `resource-leak` | Handles not released on every path, especially the error path |
| | `error-handling` | Swallowed or mislabeled failures, panics on recoverable input |
| | `k8s-manifest` | Probes, limits, image tags, secrets, privileged / host escape hatches in k8s / jkube YAML |
| Rust | `rust-unsafe` | UB and broken safety invariants behind `unsafe`, unsound safe APIs |
| | `rust-async` | Lock across `.await`, blocking the executor, dropped tasks |
| | `rust-ownership` | `Rc` cycles, runtime borrow panics, Drop order, needless allocations |
| Scala (version read from the build first) | `scala` | Collection cost (`List :+`), partial operations, Futures, per-version semantics 2.11 / 2.12 / 2.13 / 3; "Not bugs" (`:+` appends at the tail) |
| | `akka` | Akka / Pekko, classic vs typed: `sender()` and state in callbacks, blocked dispatchers, `ask`, supervision, Streams, Akka HTTP entities |
| | `cats` | Errors lost to `Either` where `Validated` was meant, lawless instances, stack safety |
| | `cats-effect` | Effects run eagerly / twice, `Resource` and fiber leaks, blocking the compute pool, `Ref` atomicity (CE 2 / 3) |
| | `zio` | Throwing code as defects, fiber supervision, scopes and layers, blocking the executor (ZIO 1 / 2) |
| Shell | `bash` | Unquoted expansions, empty vars in `rm -rf`, `set -e` that does not fire, lost subshell state, bashisms under `/bin/sh` |
| | `fish` | `set x (cmd)` line splitting, vanishing empty lists, block scope, `"\t"`; plus "Not bugs" (`; or`, no word splitting) |
| Data / messaging | `sql-postgres` | Unbounded scans, missing indexes, locking, unsafe migrations, NULL semantics |
| | `sql-clickhouse` | `ORDER BY`/partition design, mutations, `FINAL` dedup, memory-blowing joins |
| | `hbase` | Row-key hotspotting, unbounded scans, column-family / version growth |
| | `redis` | Races between commands, non-atomic collection swaps, lost TTLs, cross-slot ops, Sentinel failover; Jedis / Lettuce / Spring Data Redis / Redisson / redis-rs specifics |
| | `kafka` | Commit vs processing, idempotency, rebalances, producer acks, ordering, poison records, exactly-once claims; Java (Spring Kafka, Reactor Kafka), Rust (rdkafka), Go (confluent-kafka-go, kafka-go, sarama, franz-go) specifics |

Each lens ends with a **HARD GATE** — the evidence a finding must carry, and when to drop it.
Lens files live in `~/.config/fish/prompts/lenses/<name>.md`; a new file there is selectable at
once (in `--lens`, its completion, validation, and the `ai-review` skill). An unknown name is an
error listing the available ones. Attribution: `prompts/lenses/README.md`.

With `--verify` (or `--verify-only … --lens`) the verifier gets the same lenses, framed for its
job: knowledge to judge findings by, not places to hunt. A finding that rests on a semantics or
version item a lens corrects, or on its "Not bugs" list, is a misread — refuted. On a real
Scala change, a review without lenses read `xs :+ x` as putting the newest element at the
head, and verify confirmed it at 9/10; with the lens the review got it right.

A project's lenses go in its `.ai/config`, so every review there uses them without `--lens`:

```
review_lens=redis,reactive            # a Spring / Reactor service on Redis
review_lens=scala,akka                # a Scala service on Akka
```

They follow the code, not the model — the key is unscoped, read from the project config
(walk-up to the git root) before the global one. `--lens` replaces it for one run, `--no-lens`
drops it; the review header and `ai config status` say where the lenses came from.

### Verify (`--verify`)

A second pass that tries to **refute** each first-pass finding and gives one verdict per finding.
Nothing is hidden: every finding is kept and tagged.

| Flag | Effect |
|---|---|
| `--verify` | Run a verify pass after the review |
| `--no-verify` | Disable verify (overrides the `review_verify` config default) |
| `--verify-provider P` | Provider for the verify pass (default: `verify_provider` config, else the review provider) |
| `--verify-model M` | Model for the verify pass (default: `verify_model` config, else the default model on ollama) |
| `--verify-output FILE` | Where the verify pass is written (default: `<output>.verify.<ext>`) |

- **Terminal (no `-o`)** — the review, then a `## Verification` section.
- **File (`-o review.md`)** — the raw review lands in `review.md` as soon as pass 1 ends (so it
  survives an interrupted verify); verdicts go to `review.verify.md` (`report` → `report.verify`).
  Without `-o`, `--verify-output` has no effect.

The verifier sees the findings plus the code the review saw: the diff in git mode, the file for a
file target, nothing for a directory target. With `--agentic` it also reads the repo itself,
with the `ai-verify` skill injected. Output shape (one verdict per finding, then a tally):

```
- <finding title / file:line> — [REFUTED 9/10]
  why: <what was found in the code>
Verify: X confirmed, Y refuted, Z uncertain
```

`--verify` is opt-in (or `review_verify=1`), skipped with a note under `--brief`. The `verify`
task is configured like any other (`ai config provider claude --task verify`,
`ai models use verify MODEL`).

### Verify an existing review (`--verify-only`)

Runs **only** the verify pass over a saved review: a costly review can be verified, or
re-verified with another model, without regenerating it. The working directory is the current
one, so run it from the repo when the verifier uses `--agentic`.

| Flag | Effect |
|---|---|
| `--verify-only FILE` | The saved review to verify |
| `--verify-provider P` / `--provider P` | Verifier provider (`--verify-provider` wins; then `verify_provider`; then the review task's provider) |
| `--verify-model M` / `--model M` | Verifier model (`--verify-model` wins; then `verify_model`) |
| `--file FILE` | Code or diff to embed for the verifier. Without it (and without `--agentic`) a note says the verifier reasons from the findings text alone |
| `--verify-output FILE`, `-o FILE` | Output path (`--verify-output` wins). Default: `<review>.verify.<ext>` |
| `--agentic`, `--no-think`, `--lang`, `--dry-run` | As for a normal review |
| `--comments` | Then the comments stage below |
| `--range BASE..HEAD` | With `--comments`: the reviewed range, to anchor lines and check the diff |
| `--verdicts FILE` | With `--comments`: an existing verify file — no verify pass, comments only |

### Several review runs (`--runs`)

One run of a review — an agentic one above all — is a sample: the model decides which files to
open and goes a different way each time. On the same seven commits, three runs of qwen3.8 found
three sets of findings that did not overlap. `--runs N` runs the review N times and joins them
before verify:

```
review ×N  →  joined under "## Run K/N"  →  one verify over all of it  →  (comments)
```

- Several runs turn `--verify` on (they exist to be judged together) and refuse `--brief` and
  `--no-verify`.
- The final summary counts the verdicts from their tags (`Verify saved to: … (5 confirmed,
  7 refuted)`), not from the model's own "Verify: X confirmed…" line — on a three-run review
  qwen3.8 summed 12 verdicts as 4 + 6.
- The joined review is `<output>`; each run is kept as `<base>.runK.<ext>` with its own footer.
  A run that fails is skipped; the join fails only if none answered (`2/3 runs answered`).
- With `--comments`, the extraction merges the same problem reported by several runs into one
  comment and counts it: `"seen": 2, "runs": 3` in the JSON, `found by 2 of 3 runs` in the
  markdown. Two different problems on one line stay two comments.
- **Parallel or one at a time:** parallel runs are separate fish processes (a backgrounded fish
  function runs in the same process, one after another). `auto` runs a cloud provider in
  parallel and ollama one at a time (several local runs would not fit in memory). Each run's
  `done` line prints as soon as that run ends; on a terminal one live line
  (`1/3 done | 95s`) stands for the stage until the last run ends.

Both are config keys, scoped by provider and model — the narrowest scope wins inside a file,
the project config beats the global one, a flag beats both:

```
review_runs=1                                      # everyone (the built-in default too)
review_runs@litellm=3                              # every model of a provider
review_runs@litellm/selectel/qwen/qwen3.8-27b=3    # one model
review_parallel@claude=off                         # auto | on | off
```

Flags: `--runs N`, `--parallel`, `--no-parallel`. `ai config status` shows what the review task
resolves to and where it comes from. Three runs are a good number for a small model; a claude
review is steadier, so one run there is usually enough — and parallel claude runs spend a
subscription's usage limit three times as fast.

### Merge-request comments (`--comments`)

A third stage over the verdicts: line comments for a GitLab merge request or a GitHub pull
request. `--comments` turns `--verify` on and needs `-o`; it refuses `--brief` and
`--no-verify`.

```
ai review --last 2 --comments -o review.md        review.md, review.verify.md,
                                                  review.comments.md, review.comments.json
ai review --verify-only review.md --verdicts review.verify.md --comments --range abc~1..def
```

1. **Extraction (the verify model, one short call).** Only the review and the verdicts go in, no
   code: `meta-comments.md` asks for the `[CONFIRMED]` and `[UNCERTAIN]` findings as a JSON array
   of `file`, `line`, `quote` (one line of code, verbatim), `severity`, `status`, `body`.
   `[REFUTED]` ones are dropped. The bodies follow `--lang` (English by default); code stays as is.
   With no `[CONFIRMED]` and no `[UNCERTAIN]` verdict there is nothing to extract: no model call,
   the stage line says `skipped`, and the same files are written — an empty array, and the
   markdown with what verify refuted. Verdicts are read from their tags, also when a model
   drops the brackets (`— REFUTED 8/10` at the end of a finding's line, nowhere else); a
   verify file with no verdict found at all is not "nothing confirmed" — the model still
   gets it, and an empty result says `no verdict recognised in the verify file`.
2. **Anchoring (no model, `_ai_review_comments_anchor`).** A model's line numbers are often off
   (a cited `:24` was really `:36`), so each line is found again by its quote: in the new version
   of the file, then in the old one (removed code); the cited number only breaks ties. A quote
   that matches no single line is compared again without whitespace over two, then three
   consecutive lines — a statement the code splits that the model quoted as one line — and
   anchored on the first. A path abbreviated with `…/` is resolved by file name, a bare class
   name (`SendTicketContainerizedTest`) by the one file called `NAME.<ext>`. Then the hunks of
   `git diff -U3` tell whether the line is **in the diff** — GitLab and GitHub accept a line
   comment only there.
3. **Files next to the report.** Nothing is posted:
   - `review.comments.md` — for a human to check: per file, each comment with its line and side,
     severity, `uncertain — needs a human check` where so, the quoted line and the text. A line
     outside the diff says to post it as a general comment; one not found says `Unanchored`.
     A finding about a whole file (a missing test, a stale document) has no line: it is
     `Whole file` (`"file_level": true`), also posted as a general comment. A quote that did
     not match (models put prose there) falls back to the cited number, which is often a few
     lines off — landing on `try {` or a blank. If the cited line names none of the code the
     comment is about (`quoted` names, camelCase and CONSTANT words, case-insensitive) and a
     line within ten does, that one is taken (`"anchored_by": "nearby"`); else the cited line
     (`"anchored_by": "line"`). The comments model sees no code, so a review that names a
     method without showing it (`` `loadFromRedis()` swaps… ``) leaves it no line and no quote:
     then the first changed line of that file in the diff that names one of those words is
     taken — an added line before a context line (`"anchored_by": "name"`); with none, the
     comment stays `Whole file`. All three are flagged; the markdown always shows the real line.
     At the end, **Refuted by verify — skim before trusting** lists what verify threw out,
     each with its confidence and its `why:` — read straight from the verify file, not as
     comments and not in the JSON. Verify is a filter, not a referee: on a real work change it
     refuted the very race fixed a commit later, calling the regression pre-existing.
   - `review.comments.json` — for publishing, one shape for both platforms:

     ```json
     {"base_sha": "…", "head_sha": "…", "start_sha": "…", "runs": 3,
      "comments": [{"path": "src/…/WhitelistOrgCache.java", "side": "new", "line": 36,
                    "line_cited": 24, "anchored": true, "anchored_by": "quote", "file_level": false,
                    "code": "        localCache = Stream.concat(…)", "quote": "localCache = Stream.concat(…)",
                    "in_diff": true, "seen": 2, "runs": 3,
                    "severity": "important", "status": "confirmed", "body": "…"}]}
     ```

     GitLab: `position` = `base_sha`, `start_sha`, `head_sha`, `new_path`/`old_path` and
     `new_line` or `old_line` by `side`. GitHub: `path`, `line`, `side` `RIGHT` (new) or `LEFT`
     (old), `commit_id` = `head_sha`.

A target review (a file or directory, no range) anchors in the working tree and marks nothing as
in the diff.

### Agentic mode (`--agentic`)

`--agentic` switches the profile to `read`: the executor explores the repo read-only, and only the
minimum is embedded (diff only in git mode; the file alone for a file target; nothing for a
directory). The `ai-review` skill (verify: `ai-verify`) is injected.

| Review provider | Runs on |
|---|---|
| `claude` | claude CLI with `Read`, `Grep`, `Glob` |
| `ollama` | the runner (`agent`, default pi) with provider `ollama` — **not** the native driver |
| other | the runner |

```
$ ai review --last 1 --agentic --dry-run          # test sandbox
...
--- dry-run: prompt that would be sent to ollama via pi (profile read), skill ai-review ---
```

On a runner the context window for ollama is the server's `OLLAMA_CONTEXT_LENGTH`, not a
per-request size; there is no reasoning sidecar, and with `-o` the runner's own output is shown
instead of a line counter.

### Reasoning sidecar and `--no-think`

On the native ollama driver a thinking-capable model reasons by default, but its reasoning goes to
ollama's separate `thinking` channel and never into the answer. When the output goes to a file it
is saved next to it:

| Output | Sidecar |
|---|---|
| `-o review.md` | `review.thinking.md` |
| verify pass `review.verify.md` | `review.verify.thinking.md` |
| `ai gen commit -o msg.txt` | `msg.thinking.txt` |

A `↳ reasoning -> <path>` line is printed when one is written; an empty one is removed. No sidecar
for non-thinking models, terminal output, or runner/claude paths.

`--no-think` sends `think:false` even to a thinking model: faster, shallower, no sidecar. It is
passed to the review pass, the verify pass and `--verify-only`. It only affects the native
driver.

### Run cost in the report

Every report written with `-o` (and the verify file) ends with one HTML comment: the run label,
the wall time, the token counts and the reasoning size. The native drivers (ollama, OpenAI) report
exact counts — ollama with the generation speed, a litellm gateway with the reasoning tokens and the
cost; runners and claude get the prompt-size estimate:

```
<!-- Review - ollama - qwen3.6:latest | 78s | prompt 15234 tokens | completion 4120 tokens | 65.3 tok/s | thinking 15769 bytes -->
<!-- Review - litellm - ycloud/qwen3.6-35b-a3b/latest | 41s | prompt 15234 tokens | completion 9012 tokens (reasoning 8000) | cost 0.0681 | thinking 31002 bytes -->
<!-- Review - claude | 95s | prompt ~15k tokens (estimate) | thinking 0 bytes -->
```

It is invisible when the markdown is rendered, and it makes comparing toolkit versions or models
a matter of reading the files (`grep -h '^<!--' *.md`). A terminal run prints `done | 78s` on
stderr instead.

### Deprecated: `ai gen review`

Replaced by `ai review PATH`; the old name prints a notice and exits 1.

## `ai gen`

```
Usage: ai gen COMMAND [OPTIONS]
```

| Command | Does | Template |
|---|---|---|
| `ai gen commit` | Commit message from staged changes, else unstaged (`No changes to commit` if neither) | `meta-commit.md` |
| `ai gen summary [DIR]` | Project summary of DIR (default `.`), with its tree and README embedded | `meta-summary.md` |

| Flag | Effect |
|---|---|
| `--provider PROVIDER` | Override provider (ollama, claude, or one the runner knows) |
| `--model MODEL` | Override model |
| `-l`, `--lang LANG` | Response language (default `en`) |
| `-o`, `--output FILE` | Save output to file |
| `--dry-run` | Print the assembled prompt without invoking the model |
| `-h`, `--help` | Show help |

```
ai gen commit                        generate a commit message
ai gen commit --provider claude      on claude
ai gen commit | git commit -F -      straight into git
ai gen summary ~/work/project -o summary.md
```

Both are single-shot (profile `none`) and use the `commit` / `summary` task's provider and model.

## `ai providers`

```
Usage: ai providers [ls]       List providers (no network)
       ai providers check NAME Is it reachable right now?
```

A read-only view. ollama is served by the native driver, claude by the claude CLI, every other
provider by the runner, which also owns its configuration: add or change providers in pi
(`~/.pi/agent/models.json`) or opencode (`~/.config/opencode/config.json`).

`ai providers` (alias `ls`, `list`) — real output from the test sandbox (installed-model cache
with 3 tags, pi config with an `ollama` and a `testcloud` provider):

```
 Provider   Single call               Tools / chat  Models
 -----------------------------------------------------------------------
 ollama     native (127.0.0.1:9)      via pi        2 installed, 2 in pi
 claude     claude CLI                claude CLI    sonnet, opus, haiku
 testcloud  native, endpoint from pi  via pi        1
 -----------------------------------------------------------------------

 Reachable now? ai providers check NAME · runner: config key agent (pi) · models: ai models --provider all
```

Two executor columns, because one provider is served differently by mode: a single call
(`ai review`, `ai gen`, top-level `ai`) goes to a native driver where there is one; tools or chat
history (`--agentic`, `ai code`, `ai chat`) go through the runner. For `ollama`, "in pi" counts the
models registered in the runner — the ones `--agentic` and `ai code` can use with a real context.

`ai providers check NAME` runs the same probe as before a run:

| NAME | Check | Example |
|---|---|---|
| `ollama` | `OLLAMA_HOST` answers | `ollama: reachable (http://localhost:11434)` |
| `claude` | CLI installed | `claude: CLI installed — its connectivity is the CLI's own` |
| runner provider | the runner's `_probe` | `testcloud: not reachable (via pi) — off-network?` |
| unknown | — | `nosuch: unknown to runner pi (and not ollama / claude)` |

A provider with no URL in the runner's config (a built-in one) prints `… — can't tell` and exits
0. Unreachable or unknown exits 1.

## `ai models`

```
Usage: ai models [COMMAND] [ARGS]
```

Manages ollama models. Without a command: the installed models, no network.

| Command | Does | Network |
|---|---|---|
| (none), `list [FILTER]` | Installed models: one row per model (tags sharing a digest merged), grouped by label, with size, capabilities, the tasks using it, trial age | no |
| `FILTER` | Any other word filters the installed list by name | no |
| `--provider P` | The table of provider P: `ollama` → the local table; a runner provider → its models with context, type, price; `claude` → its aliases; `all` → one table per provider | prices: once a day |
| `info NAME[:TAG]` (alias `show`) | Installed → local details. Not installed → the ollama registry manifest: download size and RAM fit, family, params, quantization, vision, min ollama version | only when not installed |
| `try NAME:TAG [-y]` | Show registry info, confirm, pull, mark as a trial | yes |
| `keep NAME` | End a trial, keep the model | no |
| `drop NAME [-y]` | Remove a model (all its tags) and its metadata; warns if a task or the default still uses it | no |
| `search [QUERY]` | Open `https://ollama.com/search?q=QUERY` in the browser (ollama has no search API) | — |
| `label [--provider P] NAME LABEL` | Group a model under LABEL (`general` clears it); `--provider` for a cloud or claude model | no |
| `use [TASK] MODEL` | Set the default model, or a task's model | no |
| `install MODEL` (alias `pull`) | Pull a model (no trial mark) | yes |
| `rm MODEL` (alias `remove`) | Remove one tag (confirms) | no |
| `update` | Re-pull every installed tag | yes |
| `prune` (alias `cleanup`) | Find partial downloads and orphaned blobs in `~/.ollama/models`, confirm, delete | no |
| `running` (alias `ps`) | Show loaded models (`ollama ps`) | no |

A name without a tag means `:latest` everywhere (`_ai_model_norm`).

### List

Excerpt of a real `ai models`:

```
 ollama (local, native driver)
    Model                                          Size  Type       Capabilities           pi  Used for
 -------------------------------------------------------------------------------------------------------
 Coding:
    devstral-small-2:24b                        14.1 GB  dense      tools,vision           ✓   code
    laguna-xs-2.1:latest, :q4_K_M               18.9 GB  MoE 8/256  tools,thinking         ✓
 >  north-mini-code-1.0:latest                  17.3 GB  MoE 8/128  tools,thinking         ✓   default, review
    qwen2.5-coder:7b                             4.4 GB  dense      tools                  ✓   commit
 General:
    qwen3.6:latest                              21.5 GB  MoE        tools,thinking,vision      chat, summary
    qwen3.8:27b                                 16.9 GB  dense      tools,thinking,vision
   …
 -------------------------------------------------------------------------------------------------------

 14 models (15 tags), 185.5 GB on disk
 Details: ai models info NAME · try one: ai models try NAME:TAG · find: ai models search QUERY
 Per-task models: ai config status
```

- The list comes from the server (`/api/tags`) and is cached; with the server unreachable it
  shows the cache under `[ollama not reachable — showing the cached list]`.
- **Type** is `MoE USED/TOTAL` (experts per token / all experts), `MoE` or `dense`, from
  `/api/show`, cached per digest. A MoE model reads only its active experts per token, so it
  generates several times faster than a dense model of the same size on disk. Pick MoE for
  large inputs and interactive tasks, dense for small careful ones. GGUF models report the
  expert counts. For safetensors models (the MLX runner) only the tensor names tell, so they
  show plain `MoE` or `dense`. Blank: the server never answered for that model.
- **Capabilities** (`tools`, `thinking`, `vision`) come from `/api/show`, cached per digest.
- **Used for** shows `default` and every task whose provider is ollama and that sets an explicit
  `<task>_model`. Full per-task resolution: `ai config status`.
- **pi** (the runner's name): ✓ when the runner's config registers the model for provider
  `ollama`. An unregistered model gets the runner's tiny default context under `--agentic`,
  `ai code` and `ai chat`, and answers empty — register it ([adding models](howto.md)).
- Labelled groups come first (alphabetical), unlabelled models last under **General**. A trial
  shows as `trial, 3d` (`5h`, `40m`; older than a week: the start date).

### Other providers

`ai models --provider P` prints the same kind of table for a runner provider or claude, and
`--provider all` prints one table per provider: the local one, then each runner provider, then
claude. Two levels everywhere: the table is where the model runs, the groups inside are labels.

```
 litellm (native, endpoint from pi)
    Model                              Context  Type      Capabilities  pi  Price in/out per 1M  Used for
 --------------------------------------------------------------------------------------------------------
 General:
    selectel/qwen/qwen3.8-27b           131072            thinking      ✓   35 / 307
    ycloud/qwen3-235b-a22b-fp8/latest           MoE A22B  thinking      ✓   500 / 500
    ycloud/qwen3.6-35b-a3b/latest               MoE A3B   thinking      ✓   200 / 300
 --------------------------------------------------------------------------------------------------------

 claude (claude CLI)
    Model          Used for
 --------------------------
 General:
    (CLI default)  verify
    opus
 --------------------------
```

| Column | Source |
|---|---|
| Context | `contextWindow` of the model in the runner's config — blank until you fill it there (the native OpenAI driver uses it too) |
| Type | the name only: `35b-a3b` is the usual total/active notation, so `MoE A3B`. No API reports the architecture, so a name without it stays blank rather than guessed |
| Capabilities | `thinking` when the runner's config says `reasoning: true` |
| pi (the runner's name) | ✓ when the runner's config lists the model. The rows are the runner's models plus whatever the gateway's `/model/info` serves, so a model on the gateway but not in the config shows without ✓: a single call still works (the endpoint is per provider), but `--agentic` and `ai code` would give it the runner's tiny default context |
| Price in/out per 1M | a litellm gateway's `/model/info`, cached for a day in `~/.cache/ai/prices-<provider>.json`; a gateway out of reach gives the stale cache or nothing. The gateway sets the currency |
| Used for | the default and the tasks on this provider; a claude task with no model shows as `(CLI default)` |

### Info

Real output, installed and not installed:

```
$ ai models info qwen3.5:9b
Model: qwen3.5:9b
  Family:          qwen3_5
  Parameters:      9.7B
  Type:            dense
  Quantization:    nvfp4
  Format:          safetensors
  Context:         262144
  Size:            7.1 GB
  Capabilities:    completion, vision, tools, thinking

$ ai models info gemma4:e2b
Model: gemma4:e2b (not installed — from the ollama registry)
  Download:        4.3 GB · RAM 36 GB → fits
  Family:          gemma4
  Parameters:      4.6B
  Type:            dense
  Quantization:    Q4_K_M
  Vision:          yes
  Tools/thinking:  decided by ollama after install (parser gemma4)
  Draft model:     yes (speculative decoding)
  Needs ollama:    0.30.9 (you have 0.40.11)

  Try it: ai models try gemma4:e2b
```

RAM fit: `fits` up to 70 % of RAM, `tight — little room for context` above that, `won't fit`
above 100 %. Tools/thinking are known remotely only for models with an old-style template;
parser-based models decide after install. A model the registry doesn't have is an error pointing
at `https://ollama.com/library`.

Type (MoE or dense) is known before the download too. For a GGUF tag, the first 256 KB of the
model file are read with a range request: its header holds `<arch>.expert_count` and
`expert_used_count` before the tokenizer. For an MLX tag, the original `config.json` from the
manifest gives `num_experts` and `num_experts_per_tok`. A short read (the CDN drops slow
transfers) shows `unknown`, never a guess.

### Trials

`try` pulls a model and records the trial date; `keep` clears the mark; `drop` removes every tag
of the model and its metadata. `try` and `drop` take `-y` / `--yes` to skip the confirmation.
`drop` warns first if the model is still configured (`Still configured for: default, review —
those will fail until changed`).

### Labels

A label says what you keep a model for (e.g. `coding`); capabilities can't tell that. Labels are
lowercased, one per model, stored per digest in `~/.config/ai/models.json`, so every tag of a
model shares one label.

```
ai models label qwen3:30b coding     group it under Coding
ai models label qwen3:30b general    clear the label
ai models label --provider litellm ycloud/qwen3.6-35b-a3b/latest coding
```

A cloud or claude model has no digest; its label is stored under `@PROVIDER/MODEL`. `--provider`
is needed because a name alone can't tell `huihui_ai/glm…` (local) from `ycloud/…` (cloud).

### Use

```
Usage: ai models use [TASK] MODEL [--project]
       ai models use MODEL --task TASK[,TASK...] [--project]
```

| Form | Meaning |
|---|---|
| `use MODEL` | Set the default model (config key `model`); must be installed |
| `use TASK MODEL` | Set one task's model (`<task>_model`) |
| `use TASK1,TASK2 MODEL` | Several tasks at once |
| `use all MODEL` | Every task |
| `use MODEL --task TASK` | Same as `use TASK MODEL` |
| `… --project` | Write to the project `.ai/config` instead of the global config |

Tasks: `chat, code, review, verify, commit, summary, all`. A lone task name errors (the model was
forgotten); an unknown task errors. Per-task values are trusted as-is, so a task on claude or a
runner provider can take that provider's model id (`ai models use review sonnet`). If
`AI_DEFAULT_MODEL` is set and differs, `use MODEL` warns that it overrides the new value.

## `ai config`

```
Usage: ai config [SUBCOMMAND] [VALUE] [--task TASK] [--project]
```

| Subcommand | Does |
|---|---|
| (none) | Show both project and global config files |
| `provider [PROV]` | Show or set the provider (validated against ollama, claude and the runner's providers) |
| `status` | Resolved provider/model per task, with the origin of each value |
| `reset --task X` | Clear `<task>_provider` and `<task>_model` for X (or `all`) |
| `move --task X --to LAYER` | Move per-task keys between `project` and `global` (source value wins) |
| `tasks` | List known tasks |

| Flag | Effect |
|---|---|
| `--task TASK` | Apply to a task (comma-list or `all`) |
| `--project` | Write/clear in the project `.ai/config` (default: global `~/.config/ai/config`) |
| `--to {project\|global}` | Target layer for `move` |

```
ai config provider claude                          global
ai config provider claude --task review            global, one task
ai config provider claude --task review --project  project, one task
ai config reset --task all --project               clear every per-task key in the project
ai config move --task review --to global           project → global
```

`ai config status` — real output from the test sandbox (global config `provider=ollama`,
`model=config-model`, `review_model=review-model`, `commit_model=commit-model`, and
`AI_DEFAULT_MODEL=default-model` in the environment):

```
Sources:
  project = (none — no .ai/config in walked-up tree)
  global  = ~/.config/ai/config
  env     = AI_DEFAULT_MODEL=default-model

Resolved per task:
  default:  ollama / default-model                   (provider: global+top | model: env)
  chat:     ollama / default-model                   (provider: global+top | model: env)
  code:     ollama / default-model                   (provider: global+top | model: env)
  review:   ollama / review-model                    (provider: global+top | model: global)
  verify:   ollama / default-model                   (provider: global+top | model: env)
  commit:   ollama / commit-model                    (provider: global+top | model: global)
  summary:  ollama / default-model                   (provider: global+top | model: env)
```

Provider origins: `project` / `global` (a per-task key), `project+top` / `global+top` (that
layer's top-level `provider`), `default` (ollama). Model origins: `project`, `global`, `env`, or
`—` with `(not set)` (claude then uses its CLI default, a runner provider its first model, and
ollama errors).

A `<task>_model` applies only while the task's configured provider is the one in use. After
`ai config provider claude --task review`, an old ollama `review_model` is handed to claude, so
set a matching model (`ai models use review sonnet`) or `ai config reset --task review` first.

## `ai stop`

```
Usage: ai stop [OPTIONS] [MODEL]
```

| Form | Does |
|---|---|
| `ai stop` | Stop all running models |
| `ai stop MODEL` | Stop one model |
| `ai stop --server` | Kill the ollama server |

Local server only (`pgrep ollama`); prints `Ollama is not running` when there is nothing to stop.

## Config keys

Plain `key=value` lines in `~/.config/ai/config` or a project `.ai/config` (project wins).

| Key | Set with | Effect |
|---|---|---|
| `provider` | `ai config provider P` | Default provider for every task and top-level `ai` |
| `<task>_provider` | `ai config provider P --task T` | Provider for one task |
| `<task>_model` | `ai models use T MODEL` | Model for one task, used only while the provider in use is the task's provider |
| `model` | `ai models use MODEL` | Default ollama model. No fallback if unset |
| `agent` | by hand | Runner for non-claude providers: `pi` (default) or `opencode` |
| `ollama_max_ctx` | by hand | Ceiling for the native driver's `num_ctx` (default 131072) |
| `context_lines` | by hand | Git review: line budget for embedding the changed files (default 2000); `--context-lines` overrides |
| `dir_context_lines` | by hand | Directory review: line budget for embedding the directory's files (default 10000); `--context-lines` overrides |
| `review_prompt` | by hand | Review prompt depth: `auto` (default: full for claude, lean for every other model), `full`, `lean` |
| `review_runs` | by hand | How many review runs to join before verify (default 1); scoped: `review_runs@PROVIDER`, `review_runs@PROVIDER/MODEL` |
| `review_parallel` | by hand | Those runs: `auto` (default: cloud in parallel, ollama one at a time), `on`, `off`; scoped like `review_runs` |
| `review_lens` | by hand | Default lenses for reviews and their verify, comma-separated (`redis,reactive`); unscoped, best in the project's `.ai/config`; `--lens` replaces, `--no-lens` drops it |
| `cloud_driver` | by hand | Single calls to an OpenAI-API provider of the runner (litellm, …): `native` (default, direct HTTP) or `runner` (through pi / opencode) |
| `review_verify` | by hand | `1` / `true` / `yes` / `on` → `ai review` runs the verify pass by default |

Tasks: `chat`, `code`, `review`, `verify`, `commit`, `summary`. `verify_provider` / `verify_model`
are ordinary per-task keys.

## Environment variables

| Variable | Read by | Effect |
|---|---|---|
| `OLLAMA_HOST` | every ollama call (`_ai_ollama_host`) | Server address, `host:port` or URL; default `http://localhost:11434`. A non-local host is checked, never started |
| `AI_DEFAULT_MODEL` | model resolver | One-off override of config key `model`; shown as `env` in `ai config status` |
| `AI_OLLAMA_MAX_CTX` | native driver | One-off override of `ollama_max_ctx` |
| `AI_NONINTERACTIVE` | fallback prompt | Set → never ask on the terminal; an unreachable provider fails with a rerun hint |
| `OLLAMA_CONTEXT_LENGTH` | the ollama server | The server's default window (`conf.d/env.fish`, 131072). Governs runners and `ollama run`; the native driver sends its own `num_ctx` |

## Prompt templates

In `~/.config/fish/prompts/` (stowed from the repo), read fresh on every run. A missing file falls
back to a short inline prompt.

| File | Used by |
|---|---|
| `meta-commit.md` | `ai gen commit` |
| `meta-summary.md` | `ai gen summary` |
| `meta-review.md` | `ai review PATH` (target mode); `ai-review` skill |
| `meta-review-diff.md` | `ai review` (git mode); `ai-review` skill |
| `meta-verify.md` | verify pass, `--verify-only`; `ai-verify` skill |
| `meta-comments.md` | `--comments`: verified findings → MR line comments (JSON) |
| `lenses/<name>.md` | `ai review --lens NAME` (`lenses/README.md` is not a lens) |

## Files and paths

| Path | What |
|---|---|
| `~/.config/ai/config` | Global config |
| `<project>/.ai/config` | Project config (walk-up from `$PWD`, stops at the git root, `$HOME` or `/`) |
| `~/.config/ai/models.json` | Model metadata keyed by digest: `name`, `label`, `trial` |
| `~/.cache/ai-models.json` | Installed tags (from `/api/tags`), used offline by `ai models` and completion |
| `~/.cache/ai/model-caps.json` | Capabilities per digest |
| `~/.cache/ai/model-arch.json` | Architecture per digest (`MoE 8/128`, `MoE`, `dense`) |
| `~/.cache/ai/prices-<provider>.json` | Cloud prices from a litellm gateway, refreshed after a day |
| `~/.agents/skills/{ai-review,ai-verify}/` | Installed skills (pi, opencode; our runs read `SKILL.md` from here) |
| `~/.claude/skills/{ai-review,ai-verify}` | The same skills for claude |
| `~/.config/opencode/agents/ai-{none,read,edit}.md` | opencode profiles for the runner |
| `~/.pi/agent/models.json` | pi's providers and models (pi's file, not in dotfiles) |
| `~/.config/opencode/config.json` | opencode's providers (opencode's file, not in dotfiles) |
| `<report>.verify.<ext>` | Verify output next to a review written with `--verify -o` or by `--verify-only` |
| `<report>.thinking.<ext>` | Reasoning sidecar (native ollama, thinking models) |

## Tab-completion

`completions/ai.fish` completes:

- subcommands of `ai`, `gen`, `config`, `models`, `providers`;
- flags per subcommand;
- provider names from `_ai_providers` (ollama, claude, and the runner's providers) for every
  `--provider`, `--verify-provider`, `ai config provider`, `ai providers check`, and
  `ai models --provider` (plus `all`);
- model names via `_ai_complete_models`, following `--provider` on the same line (for
  `--verify-model`: `--verify-provider` first): ollama or none → the installed-model cache (works
  with the server down); claude → `sonnet`, `opus`, `haiku`; any other provider → the runner's
  models for it. `--verify-model` with no provider also offers the claude aliases;
- task names (and `all`) for `--task` and the first argument of `ai models use`;
- lens names for `--lens`, comma-stacked (`--lens crypto,<Tab>` offers the rest);
- running models for `ai stop`.

Known gap: top-level `ai --provider X -m <Tab>` completes nothing (fish takes `X` for a
subcommand). fish caches completions per session: after editing, `exec fish`.

## Troubleshooting

**`ollama: no model configured — set one with: ai models use MODEL`**
No default model and no task model. `ai models use MODEL` (must be installed), or
`ai models use TASK MODEL`.

**`Provider X: unknown to runner pi — configure it in pi, or pick another provider (ai providers)`**
The runner's config has no provider X. Add it to `~/.pi/agent/models.json` (or opencode's config
with `agent=opencode`); `ai models --provider all` lists what the runner knows.

**`X unreachable (via pi) — off-network? Rerun with --provider ollama`**
The probe failed and there was no terminal to ask on (or `AI_NONINTERACTIVE` is set, or no
default ollama model exists). Rerun with `--provider ollama`, or check with
`ai providers check X`.

**`Unknown runner 'X' in config key agent (valid: pi, opencode)`**
Fix the `agent=` line in the config.

**`Error: pi is not installed — brew install pi-coding-agent`** / **`Error: opencode is not installed — brew install opencode`** / **`Error: claude is not installed`**
The executor's CLI is missing from `$PATH`.

**`Note: skill ai-review is not installed (stow agents) — running without it`**
The `agents` stow package isn't installed: `./install.sh` (or `mkdir -p ~/.agents/skills ~/.claude/skills ~/.config/opencode/agents && stow agents`).

**`ollama: prompt ~N tokens needs ~M context, over the 131072 ceiling…`**
The native driver refuses to truncate. Shrink the prompt (`--context-lines 0`, `--file`, a
smaller range), use `--agentic`, or raise `ollama_max_ctx` / `AI_OLLAMA_MAX_CTX` if you have the
RAM.

**`Error: ollama at HOST is not reachable`** / **`Error: Ollama failed to start`**
A remote `OLLAMA_HOST` is down (it is never started for you), or a local `ollama serve` didn't come
up within 10 s.

**`No output written — FILE is empty…`**
The model returned nothing: an interrupted stream or a prompt too big for the window. Retry with
`--context-lines 0`; on a runner, check the context window (next item).

**An agentic run on ollama comes back empty**
Runners use the server's `OLLAMA_CONTEXT_LENGTH`; a prompt plus file reads that overflow it get
truncated. Register the model in the runner with a matching context window — see
[howto](howto.md#agentic-runs-on-ollama-come-back-empty).

**Broken symlinks in `~/.config/fish/functions/`**
After functions are deleted from the repo:

```
find ~/.config/fish/functions/ -maxdepth 1 -type l ! -exec test -e {} \; -print -delete
stow --restow fish
```
