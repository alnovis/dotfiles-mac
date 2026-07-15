# Dotfiles (macOS)

Development environment configuration for MacBook Pro M4 Max (36GB), optimized for Scala, Rust, Java, and Kotlin development.

## Components

| Component | Description |
|-----------|-------------|
| **nvim** | Neovim (LazyVim) with LSP for Scala, Rust, Java, Kotlin |
| **kitty** | Kitty terminal with Japanesque theme |
| **fish** | Fish shell with dev aliases and SDKMAN integration |
| **leetcode** | Offline LeetCode runner for Scala 3 and Rust |

## Quick Install

```bash
# Install dependencies
brew install neovim fish stow lazygit bat jq macmon ollama opencode pi-coding-agent
brew install --cask kitty orbstack intellij-idea-ce rustrover

# Clone and apply
git clone git@github.com:alnovis/dotfiles-mac.git ~/dotfiles-mac
cd ~/dotfiles-mac
./install.sh

# Set fish as default shell
echo /opt/homebrew/bin/fish | sudo tee -a /etc/shells
chsh -s /opt/homebrew/bin/fish
```

> **Note:** Kitty config uses `/opt/homebrew/bin/fish` (Apple Silicon). For Intel Macs change the path in `kitty/kitty.conf`.

## Post-Install

Fish theme (bobthefish) and Oh My Fish are installed automatically by `install.sh`. If needed manually:

```bash
curl -sL https://raw.githubusercontent.com/oh-my-fish/oh-my-fish/master/bin/install | fish
omf install bobthefish
```

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
- Neo-tree — file explorer with git status
- Telescope — fuzzy finder for files and text
- Gitsigns — inline git blame and hunk management
- Lazygit — terminal UI for git (`Space gg`)
- Spectre — project-wide search and replace (`Space sr`)
- Hardtime — vim motion trainer (`Space uh` to toggle)
- CodeCompanion — local AI via Ollama (`Space ac/ag/ai`)
- Diffview — git diff viewer (`Space gd/gh`)
- conform.nvim — auto-format on save (scalafmt, rustfmt, ktlint, google-java-format)

**Key bindings:**
- All hotkeys are duplicated for Cyrillic keyboard layout
- `Ctrl+Click` — go to definition
- `Ctrl+Alt+Click` — find usages
- `Ctrl+Alt+Left/Right` — navigate back/forward
- `Ctrl+S` — save
- `Space e` — toggle file tree
- `Space ff` — find file
- `Space fg` — live grep
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
| Vertical split | `Cmd+D` |
| Horizontal split | `Cmd+Shift+D` |
| Navigate splits | `Ctrl+Shift+H/L/K/J` |
| Toggle stack layout | `Cmd+Shift+Enter` |
| Font size +/−/reset | `Cmd+=/−/0` |
| Copy/paste | `Cmd+C/V` (+ Cyrillic `Cmd+С/М`) |

## Fish

**Environment defaults** (`fish/.config/fish/conf.d/env.fish`):
- `EDITOR` / `VISUAL` → `nvim`
- `LANG` → `en_US.UTF-8`
- `OLLAMA_CONTEXT_LENGTH` → `32768` (raises Ollama's 4K default for local-model agents)
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
- `clipclean` — dedent and trim clipboard (removes common leading indentation)
- `cheat` — cheat sheet for a command via cheat.sh (`cheat tar`, `cheat git rebase`)

*Image clipboard (macOS):*
- `clipimg` — copy an image file into the clipboard (`clipimg shot.png`)
- `pasteimg` — save the clipboard image to a file (`pasteimg shot.png`); output format is taken from the extension, converting if needed (e.g. a copied PNG saved as `.jpg`)
- Both support `.png .jpg/.jpeg .tif/.tiff .gif .bmp`

*Files / paths:*
- `fpath` — print a file's absolute path, like `pwd` for files (`fpath gitlab.log`); searches NAME recursively below the current dir (or a given DIR: `fpath ~/work '*.log'`), matches NAME as a glob, includes ignored/hidden files, and prints every match one per line. A path prefix on NAME folds into the search dir, so the basename is searched below it (`fpath ../project/docs/notes.md`)

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

*AI — unified `ai` command with multi-provider support (Ollama, Claude), per-task / per-project config, named sessions, and Tab-completion. Full docs: [docs/fish/ai/](docs/fish/ai/).*

**Core / chat:**
- `ai [PROMPT]` — one-shot prompt or interactive chat (`ai "question"`, `git diff | ai "review"`)
  - `-m/--model`, `-t/--think` (ollama), `--provider`, `--dry-run` (print assembled prompt without invoking)
- `ai chat` — interactive chat (default ollama)
  - `--session NAME` / `-s NAME` — start/resume persistent session (ollama only, see Sessions below)
  - `-c` continue last session, `--new` error if exists, `--global` force global scope, `--system "..."`
- `ai code` — pi with file edits off by default (read + bash stay on, prompted), `-e/--edit` to allow edits (ollama only)

**Review (auto-detected mode from positional):**
- `ai review` — git mode: branch vs base (auto-detects develop/main/master)
- `ai review BRANCH` — git mode: vs that branch
- `ai review --last [N]` / `--commit SHA` / `--file FILE` — git mode: last N commits / specific commit / single file filter
- `ai review PATH` — target mode: project (dir) or single-file review
- `ai review FILE --with-project-context` — target mode: file + parent project context
- Common: `--brief`, `--lang LANG`, `--lang-all LANG` (git only), `-o/--output FILE`, `--dry-run`

**Generation:**
- `ai gen commit` — commit message from staged/unstaged diff
- `ai gen summary [DIR]` — project summary
- Common: `--provider`, `--model`, `--lang`, `-o/--output FILE`, `--dry-run`

**Sessions** (persistent chat history, ollama only — claude conversations use `claude --resume` natively):
- Storage: walk-up `.ai/sessions/<name>.jsonl` (project) → `~/.config/ai/sessions/` (global)
- `ai sessions ls [--archived|--all]` / `show NAME` / `info NAME` — browse + render
- `ai sessions search QUERY [--name PAT] [--since DATE]` / `stats [--all]` — find + aggregate
- `ai sessions rm / rename / clear / edit` — modify
- `ai sessions branch / archive / restore / move --to {project|global}` — lifecycle
- `ai sessions export / import / pin / unpin` — share + lock provider/model per session
- Context management: rolling summary + sliding window (configurable thresholds)

**Config (per-task / per-project, with global fallback):**
- `ai config` — show project + global config side-by-side
- `ai config status` — resolved provider/model per task with origin (`project / global / env / default`)
- `ai config provider PROV [--task X] [--project]` — set provider scoped
- `ai config reset --task {X|all} [--project]` — clear per-task overrides
- `ai config move --task X --to {project|global}` — relocate per-task keys
- `ai config tasks` — list known tasks (chat, code, review, commit, summary)
- Resolver chain: project `.ai/config` → global `~/.config/ai/config` → `AI_DEFAULT_MODEL` env → fallback

**Models:**
- `ai models` / `ai models list [FILTER]` — RAM-filtered list (`--all` for everything)
- Shows "Active selection" header per task + "Used for" tag per model
- `ai models install / rm / use MODEL [--task X] [--project]` — manage models, set scoped defaults
- `ai models update / info / prune / running` — maintenance

**Prompt templates** (`~/.config/fish/prompts/`, overridable, fall back to inline defaults):
- `meta-commit.md`, `meta-summary.md` — generation
- `meta-review.md` (project state), `meta-review-diff.md` (git diff)
- `meta-session-summary.md` (rolling summary for long sessions)

**Other:**
- `ai stop [MODEL]` — stop one or all running models, `--server` to kill Ollama entirely
- `opencode` — run OpenCode TUI with Ollama auto-start

*LeetCode:*
- `lc-run` — run LeetCode solution with `@test` cases (Scala 3, Rust)

> LeetCode runner docs: [docs/leetcode.md](docs/leetcode.md)

## Dev Tools

| Tool | Install |
|------|---------|
| SDKMAN | `curl -s "https://get.sdkman.io" \| bash` |
| JDK 21 | `sdk install java 21.0.5-tem` |
| Maven | `sdk install maven` |
| Gradle | `sdk install gradle` |
| Scala | `brew install sbt coursier/formulas/coursier && cs setup` |
| Rust | `curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \| sh` |
| Ollama | `brew install ollama` |
| OpenCode | `brew install opencode` |
| Pi | `brew install pi-coding-agent` |

**AI Models:**

```bash
ai models                                   # browse available models (RAM-filtered)
ai models install qwen3.5:9b                # install a model
ai models use qwen3.5:9b                    # set as global default
ai models use qwen2.5-coder:7b --task commit  # per-task default
ai config status                            # see resolved provider+model per task
```

**AI Tools:**

| Tool | Purpose | Usage |
|------|---------|-------|
| `ai` | Multi-provider toolkit (Ollama/Claude) with per-task/per-project config | `ai "question"`, `git diff \| ai "review this"` |
| `ai review` | Code review — git changes or project state (auto-detected) | `ai review`, `ai review src/Foo.scala`, `ai review --last 3` |
| `ai gen` | Content generation (commit, summary) | `ai gen commit`, `ai gen summary -o summary.md` |
| `ai chat` | Chat — stateless or persistent (`--session NAME`, ollama only) | `ai chat -s debug-foo`, `ai chat -c` |
| `ai sessions` | Session management (ls/show/search/branch/pin/...) | `ai sessions ls`, `ai sessions search migration` |
| `ai config` | Provider/model config — global + per-project + per-task | `ai config status`, `ai config provider claude --task review` |
| `ai models` | Model manager (install/use/info, per-task defaults) | `ai models use qwen3.5:9b --task chat` |
| `ai code` | AI-assisted coding (pi + Ollama) | `ai code @src/` |
| `pi` | Coding agent (multi-provider, Ollama) | `pi --model ollama/qwen3.5:9b` |
| `claude` | Cloud AI coding agent (Anthropic) | `claude "analyze project"` |

## macOS Apps

- [Rectangle](https://rectangleapp.com/) — window management
- [OrbStack](https://orbstack.dev/) — Docker runtime
- [IntelliJ IDEA CE](https://www.jetbrains.com/idea/) — Scala/Java/Kotlin IDE
- [RustRover](https://www.jetbrains.com/rust/) — Rust IDE

## Docs

| Document | Description |
|----------|-------------|
| [docs/fish/ai/](docs/fish/ai/) | AI toolkit — architecture, reference, sessions, how-to |
| [docs/nvim/keymaps.md](docs/nvim/keymaps.md) | Full Neovim keymaps reference |
| [docs/leetcode.md](docs/leetcode.md) | LeetCode offline runner guide |

## Global Gitignore

`.gitignore_global` covers common artifacts for Java (jdtls), Scala (Metals/Bloop), Rust, Kotlin (Gradle), IDEs (IntelliJ, VS Code), and macOS.

## Uninstall

```bash
cd ~/dotfiles-mac
./install.sh unstow
```
