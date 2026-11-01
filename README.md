# Dotfiles (macOS)

Development environment configuration for MacBook Pro M4 Max (36GB), optimized for Scala, Rust, Java, and Kotlin development.

## Components

| Component | Description |
|-----------|-------------|
| **nvim** | Neovim (LazyVim) with LSP for Scala, Rust, Java, Kotlin |
| **kitty** | Kitty terminal with Japanesque theme |
| **fish** | Fish shell with dev aliases and SDKMAN integration |
| **agents** | `ai` toolkit add-ons for agent CLIs: the `ai-review` / `ai-verify` skills (→ `~/.agents/skills`, `~/.claude/skills`) and opencode runner profiles (→ `~/.config/opencode/agents`) |
| **leetcode** | Offline LeetCode runner for Scala 3 and Rust |

## Quick Install

```bash
# Clone and apply (needs Homebrew; install.sh runs `brew bundle` from Brewfile, stows nvim/kitty/fish/agents, installs fish plugins)
git clone git@github.com:alnovis/dotfiles-mac.git ~/dotfiles-mac
cd ~/dotfiles-mac
./install.sh

# Set fish as default shell
echo /opt/homebrew/bin/fish | sudo tee -a /etc/shells
chsh -s /opt/homebrew/bin/fish
```

> **Note:** Kitty config uses `/opt/homebrew/bin/fish` (Apple Silicon). For Intel Macs change the path in `kitty/kitty.conf`.

## Post-Install

Fish plugins (bobthefish theme, sdkman-for-fish) are managed by [fisher](https://github.com/jorgebucaran/fisher) and installed automatically by `install.sh` from `fish/.config/fish/fish_plugins`. If needed manually:

```fish
curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source && fisher update
```

Adding a plugin with `fisher install <repo>` updates the stowed `fish_plugins`, so commit that file afterwards.

LSP servers (Metals, rust-analyzer, jdtls, kotlin-language-server) are installed automatically by Mason on first Neovim launch.

Formatters (scalafmt, ktlint, google-java-format) are also managed by Mason. The exception is `rustfmt`:

```bash
rustup component add rustfmt
```

## Neovim

Built on [LazyVim](https://www.lazyvim.org/) with the following customizations:

**Theme:** Kanagawa Wave

**Language support:**

| Language | LSP | Compile | Run | Test | Package |
|----------|-----|---------|-----|------|---------|
| Scala | Metals | `Space sc` | `Space sr` | `Space st` | — |
| Rust | rust-analyzer | `Space rc` | `Space rr` | `Space rt` | — |
| Java (Maven) | jdtls | `Space mc` | `Space mr` | `Space mt` | `Space mp` |
| Java (Gradle) | jdtls | `Space gc` | `Space gr` | `Space gt` | — |
| Kotlin | kotlin-language-server | `Space kc` | `Space kr` | `Space kt` | — |
| Docker | dockerfile LSP | — | — | — | — |

**Plugins:**
- Neo-tree — file explorer with git status (`Space e`)
- Snacks picker — fuzzy finder for files and text (LazyVim default)
- Gitsigns — inline git blame and hunk management
- Lazygit — terminal UI for git (`Space gg`)
- grug-far — project-wide search and replace (`Space sr` on a visual selection; in normal mode `Space sr` is sbt run)
- Hardtime — vim motion trainer (`Space uh` to toggle)
- CodeCompanion — local AI via Ollama (`Space ac/ag/ai`)
- Diffview — git diff viewer (`Space gd/gh`)
- conform.nvim — auto-format on save (scalafmt, rustfmt, ktlint, google-java-format)

**Key bindings:**
- Custom hotkeys (save, `jk`, move lines, clipboard, terminal, build, AI) are duplicated for the Cyrillic layout
- `Ctrl+Click` — go to definition
- `Ctrl+Alt+Click` — find usages
- `Ctrl+Alt+Left/Right` — navigate back/forward
- `Ctrl+S` — save
- `Space e` — toggle file tree
- `Space ff` — find file
- `Space /` — live grep
- `Space gg` — lazygit
- `Space lr` — run LeetCode tests

> Full keymaps reference: [docs/nvim/keymaps.md](docs/nvim/keymaps.md)

## Kitty

- Japanesque color theme (loaded from `current-theme.conf`)
- Layouts: splits + stack (`enabled_layouts splits,stack`)

**Keybindings:**

| Action | Shortcut |
|--------|----------|
| New tab | `Cmd+T` |
| Close tab | `Cmd+W` |
| Switch tab 1-5 | `Cmd+1-5` |
| Next/prev tab | `Cmd+Shift+]/[` |
| New split (auto direction) | `Cmd+Enter` |
| Horizontal split | `Cmd+Shift+Enter` |
| Rotate splits | `Cmd+Shift+R` |
| Navigate splits | `Ctrl+Shift+H/L/K/J` |
| Toggle stack layout (zoom) | `Cmd+Shift+Z` |
| Font size +/−/reset | `Cmd+=/−/0` |
| Copy/paste | `Cmd+C/V` (+ Cyrillic `Cmd+С/М`) |

## Fish

**Environment defaults** (`fish/.config/fish/conf.d/env.fish`):
- `EDITOR` / `VISUAL` → `nvim`
- `LANG` → `en_US.UTF-8`
- `OLLAMA_CONTEXT_LENGTH` → `131072` (the ollama server's default window, used by the runners pi/opencode and `ollama run`; the `ai` native driver sizes `num_ctx` per request instead)
- `JAVA_HOME` is owned by SDKMAN when installed; `config.fish` only sets a fallback for non-SDKMAN machines
- Host-specific overrides: create `~/.config/fish/conf.d/env.local.fish` (gitignored), auto-sourced

**Aliases:**
- Navigation: `..`, `...`, `work` (~/work), `ll` (ls -la), `la` (ls -A)
- Git: `g`, `gs`, `gl`, `gp`, `gpl`, `gc`, `gca`, `gco`, `gb`, `gd`, `ga`, `gaa`, `lg` (lazygit)
- Editor: `v`/`vi`/`vim` → nvim, `idea` → IntelliJ, `rr` → RustRover
- Docker: `d`, `dc`, `dps`
- Pager: `less`/`PAGER` → `bat`

**Functions:**

All functions support `-h/--help`.

*Text:*
- `trim` — trim leading/trailing whitespace per line (args or stdin)
- `clipclean` — dedent and trim clipboard (removes common leading indentation); `-f/--flat` strips all leading whitespace
- `cheat` — cheat sheet for a command via cheat.sh (`cheat tar`, `cheat git rebase`)
- `table` — align tab-separated lines from stdin into columns (`... | table --header --right 2`); widths are measured without colour codes, so cells may carry `set_color`; `--max COL:N` caps a column with `~`, a line without a tab prints as-is (a group title). `ai models list` and `ai config status` are built on it

*Image clipboard (macOS):*
- `clipimg` — copy an image file into the clipboard (`clipimg shot.png`)
- `pasteimg` — save the clipboard image to a file (`pasteimg shot.png`); output format is taken from the extension, converting if needed (e.g. a copied PNG saved as `.jpg`)
- Both support `.png .jpg/.jpeg .tif/.tiff .gif .bmp`

*Files / paths:*
- `take` — `mkdir -p` + `cd`; given a git URL clones and cds, given an archive extracts and cds
- `fpath` — print a file's absolute path, like `pwd` for files (`fpath gitlab.log`); searches NAME recursively below the current dir (or a given DIR: `fpath ~/work '*.log'`), matches NAME as a glob, includes ignored/hidden files, and prints every match one per line. A path prefix on NAME folds into the search dir, so the basename is searched below it (`fpath ../project/docs/notes.md`)

*Shell introspection:*
- `describe` — inspect a fish function like psql's `\d` (`describe gstat`): a header card (name, description, source `file:line`, type) followed by the syntax-highlighted body via `fish_indent --ansi`. Flags: `-d/--description` (summary only), `-p/--path` (source file only, e.g. `v (describe -p gstat)`), `-b/--body` (highlighted body only), `--plain` (no ANSI). Colors/highlighting auto-disable off a tty. Non-function names fall back to `type` output. Tab-completes your functions.

*Quick commands:*
- `q` — lightweight named commands: `q add NAME CMD` (or `q add NAME` to write it in `$EDITOR`), then `q NAME [args…]`; also `q ls / show / edit / rm`. Stored in `~/.config/quick/` (machine-local, not in this repo)

*Git:*
- `clipcommit` — git commit using clipboard as message (`-y -a -p -d -e --no-color`)
- `gstat` — colored git changes summary (staged, unstaged, untracked with `--stat`)
- `gbranch` — branch overview: commits and diff stat vs base (`gbranch [BASE]`)
- `gsquash` — squash commits: `reset --soft` (default) or `merge --squash` (`-m`)
- `gundo` — soft undo last commit, keep changes staged (with confirmation)
- `gclean` — delete local branches already merged into base branch
- `gfresh` — fetch + rebase current branch onto base (auto-stashes changes)
- `gwip` / `gunwip` — quick WIP commit of all changes / undo WIP commit
- `grelease` — create or re-release a git tag: commit + tag + push (`grelease [patch|minor|major|VERSION] [MESSAGE]`)

*Docker:*
- `registry-login` — docker login to private registry (uses `CI_REGISTRY` + `CI_PERSONAL_TOKEN`)
- `set-ci-token` — set/update `CI_PERSONAL_TOKEN` or `CI_REGISTRY` (`-r/--registry`)
- `dclean` — remove stopped containers, dangling images, unused volumes (`-a` for full prune)
- `dlogs` — docker compose logs with service filter and grep (`-g/--grep`, `-n/--lines`)

*Kube — single `k` dispatcher for the local k3s cluster, modelled on the `ai` toolkit: a closed set of helpers (each with its own `--help` and flags) plus `k x …` for raw kubectl. No implicit passthrough. Full docs: [docs/fish/kube/toolkit.md](docs/fish/kube/toolkit.md).*
- `k pods [NS]` — pod overview, defaults to all namespaces; non-Running red, not-ready yellow
- `k log <sub>` — tail a pod's logs by name substring (`-f` follow, `-g` grep, `-t` tail, `-p` previous, `-c` container)
- `k sh <sub> [CMD]` — exec into a pod; no CMD opens an interactive shell (bash→sh)
- `k desc <sub>` — describe pod + recent events ("why won't it come up?")
- `k ns [NAME]` — show namespaces / switch the default
- `k pf <sub> <PORT>` — port-forward (`PORT` = `LOCAL:REMOTE` or single)
- `k x <args…>` — raw kubectl (`k x apply -f`, `k x get pods -A`, …) with the kubeconfig baked in and full native completion
- Pods match by name **substring** across namespaces (`-n` to scope); completion is entirely ours (helpers) or bridged to `kubectl __complete` (`k x`)
- KUBECONFIG: `$K_KUBECONFIG` (required, no default — `set -Ux K_KUBECONFIG /path/to/kubeconfig`)

*AI — one `ai` command over local and cloud models, per-task / per-project config, Tab-completion. Full docs: [docs/fish/ai/](docs/fish/ai/).*

**How it runs a model** — two kinds of executor, picked per call:
- **native ollama driver** — single-shot calls to local models; sizes `num_ctx` to each prompt
- **runners** — agent CLIs behind one contract: **pi** or **opencode** (config key `agent`, default pi) for every non-claude provider, local or cloud; the **claude** CLI for `--provider claude`. Providers and their keys live in the runner's own config (pi `~/.pi/agent/models.json`, opencode `~/.config/opencode/config.json`) — `ai` keeps no registry
- What goes into the prompt depends on the mode, not the provider: by default everything is embedded (diff + changed files, or file / tree / README); with `--agentic` only the diff or the file, and the executor explores the repo read-only with the `ai-review` / `ai-verify` skill injected

**Core / chat / code:**
- `ai [PROMPT]` — one-shot prompt, or `ollama run` with no arguments (`ai "question"`, `git diff | ai "review"`)
  - `-m/--model`, `-t/--think`, `--no-think`, `--agentic`, `--provider`, `--dry-run` (print the prompt and the executor that would get it)
- `ai chat [MODEL]` — interactive chat with the chat task's provider; history lives in the runner / claude CLI: `-c` continue the last chat, `-r` pick one; `--provider`, `--dry-run`
- `ai code` — interactive coding session with the code task's provider (pi/opencode, or claude); no file edits by default, `-e/--edit` allows them; `--provider`, `--model`, `--dry-run`

**Review (mode auto-detected from the positional):**
- `ai review` — git mode: branch vs base (develop/main/master); `ai review BRANCH` — vs that branch
- `ai review --last [N]` / `--commit SHA` / `--file FILE` — last N commits / one commit / one file of the diff
- `ai review PATH` — target mode: a directory or a single file; `--with-project-context` adds the project tree/README to a file review
- Common: `--provider`, `--model`, `--brief`, `--lang LANG`, `-o/--output FILE`, `--dry-run`
- `--lens NAME[,NAME…]` — specialist checklists (security, quality, Rust, shell, data/messaging; see `prompts/lenses/`)
- `--agentic` — the executor reads the repo itself (read-only tools + the `ai-review` skill)
- `--no-think` — fast pass: disable a thinking model's reasoning
- `--verify` / `--verify-provider P` / `--verify-model M` — adversarial second pass that tries to refute each finding; with `-o` it goes to `<output>.verify.<ext>`; `--verify-only FILE` re-verifies a saved review
- `--context-lines N` — line budget for embedding whole files: the changed files in git mode (default 2000), a directory target's files (default 10000); config keys `context_lines` / `dir_context_lines`
- Git only: `--lang-all LANG`, `--max-lines N` (diff cap, default 500)

**Generation:**
- `ai gen commit` — commit message from the staged (else unstaged) diff
- `ai gen summary [DIR]` — project summary
- Common: `--provider`, `--model`, `--lang`, `-o/--output FILE`, `--dry-run`

**Providers:**
- `ai providers` — every provider and the executor serving it (no network)
- `ai providers check NAME` — reachable right now? It is the same ≤2 s probe `ai` runs before every cloud call; when that probe fails on a terminal, `ai` offers to run on local ollama instead

**Config (per-task / per-project, global fallback):**
- `ai config` / `ai config status` — raw config, and the resolved provider/model per task with origin
- `ai config provider PROV [--task X] [--project]`, `ai config reset --task {X|all} [--project]`, `ai config move --task X --to {project|global}`, `ai config tasks`
- Model resolution: task model (project → global) → `AI_DEFAULT_MODEL` (one-off override) → config key `model` (project → global); nothing set is an error, not a silent default
- Native ollama: `OLLAMA_HOST`; context ceiling `ollama_max_ctx` / `AI_OLLAMA_MAX_CTX` (default 131072)

**Models:**
- `ai models [FILTER]` — installed models: one row per model, grouped by label, with size, capabilities, the tasks using it and trial age (no network); `--provider P|all` — a runner provider's models
- `ai models info NAME[:TAG]` — details; for a model not installed, read from the ollama registry before downloading (size, RAM fit, params, quantization, vision, …)
- `ai models try NAME:TAG` / `keep` / `drop` — pull a model as a trial, then keep or remove it
- `ai models search [QUERY]` — open ollama.com search (ollama has no search API)
- `ai models label NAME LABEL` — group a model (`general` clears); `ai models use [TASK] MODEL [--project]` — default or per-task model
- `ai models install / rm / update / prune / running` — maintenance

**Prompts and skills:**
- `~/.config/fish/prompts/`: `meta-commit.md`, `meta-summary.md`, `meta-review.md` (project state), `meta-review-diff.md` (git diff), `meta-verify.md`, `lenses/<name>.md` (see `lenses/README.md`)
- `agents/.agents/skills/{ai-review,ai-verify}/` — the agentic procedure; `references/` links to the prompts above, so the rules have one source. Also usable by hand in claude / pi: `/ai-review [BASE|PATH] [--lens …]`

**Other:**
- `ai stop [MODEL]` — stop one or all running models, `--server` to kill Ollama entirely
- `opencode` — run OpenCode TUI with Ollama auto-start
- Tests: `tests/ai/run.fish` — golden `--dry-run` prompts + help smoke checks, offline, about a second

*LeetCode:*
- `lc-run` — run LeetCode solution with `@test` cases (Scala 3, Rust)
- `lc-init` — generate a Cargo project around the `.rs` solutions so rust-analyzer works on them

> LeetCode runner docs: [docs/leetcode.md](docs/leetcode.md)

## Dev Tools

| Tool | Install |
|------|---------|
| SDKMAN | `curl -s "https://get.sdkman.io" \| bash` |
| JDK | `sdk install java 25.0.2-tem` (17 and 21 also installed; switch with `sdk use java …`) |
| Maven | `sdk install maven` |
| Gradle | `sdk install gradle` |
| Scala | `brew install sbt coursier/formulas/coursier && cs setup` |
| Rust | `curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \| sh` |
| Ollama | `brew install ollama` |
| OpenCode | `brew install opencode` |
| Pi | `brew install pi-coding-agent` |

**AI Models:**

```bash
ai models                                   # installed models
ai models info qwen3:30b                    # will it fit? (read from the registry, nothing downloaded)
ai models try qwen3:30b                     # pull as a trial; later: ai models keep / drop qwen3:30b
ai models use qwen3.5:9b                    # default model (config key `model`)
ai models use commit qwen2.5-coder:7b       # per-task model
ai config status                            # resolved provider + model per task
```

**AI Tools:**

| Tool | Purpose | Usage |
|------|---------|-------|
| `ai` | Local + cloud models through one command, per-task/per-project config | `ai "question"`, `git diff \| ai "review this"` |
| `ai review` | Code review — git changes or project state (auto-detected) | `ai review`, `ai review src/Foo.scala --lens crypto`, `ai review --last 3 --agentic` |
| `ai gen` | Content generation (commit, summary) | `ai gen commit`, `ai gen summary -o summary.md` |
| `ai chat` | Interactive chat; history via the runner / claude CLI | `ai chat`, `ai chat -c`, `ai chat --provider claude` |
| `ai code` | Interactive coding session (pi/opencode, or claude) | `ai code @src/`, `ai code -e` |
| `ai providers` | Providers and their executors; reachability | `ai providers`, `ai providers check litellm` |
| `ai config` | Provider/model config — global + per-project + per-task | `ai config status`, `ai config provider claude --task review` |
| `ai models` | Installed models, registry info, trials, labels | `ai models info qwen3:30b`, `ai models use review qwen3.5:27b` |
| `pi` | Coding agent, the default runner (local + cloud providers) | `pi --model ollama/qwen3.5:9b` |
| `opencode` | Coding agent, alternative runner (`agent=opencode`) | `opencode` |
| `claude` | Claude Code CLI, runner for `--provider claude` | `claude "analyze project"` |

## macOS Apps

- [Rectangle](https://rectangleapp.com/) — window management
- [OrbStack](https://orbstack.dev/) — Docker runtime
- [IntelliJ IDEA](https://www.jetbrains.com/idea/) — Scala/Java/Kotlin IDE
- [RustRover](https://www.jetbrains.com/rust/) — Rust IDE

## Docs

| Document | Description |
|----------|-------------|
| [docs/fish/ai/](docs/fish/ai/) | AI toolkit — architecture, reference, how-to |
| [docs/fish/kube/toolkit.md](docs/fish/kube/toolkit.md) | Kube toolkit — `k` dispatcher, helpers, `k x` raw kubectl |
| [docs/nvim/keymaps.md](docs/nvim/keymaps.md) | Full Neovim keymaps reference |
| [docs/leetcode.md](docs/leetcode.md) | LeetCode offline runner guide |

## Global Gitignore

`.gitignore_global` covers common artifacts for Java (jdtls), Scala (Metals/Bloop), Rust, Kotlin (Gradle), IDEs (IntelliJ, VS Code), and macOS.

## Uninstall

```bash
cd ~/dotfiles-mac
./install.sh unstow
```
