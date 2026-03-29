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
brew install neovim fish stow lazygit bat jq ollama aider opencode pi-coding-agent
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

> Full keymaps reference: [docs/nvim-keymaps.md](docs/nvim-keymaps.md)

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

*AI (Ollama) — unified `ai` command with subcommands and Tab-completion:*
- `ai [PROMPT]` — interactive chat or one-shot prompt (`ai "question"`, `git diff | ai "review"`)
  - `-m/--model` override model, `-t/--think` enable thinking mode
- `ai chat` — chat model (default: llama3.1:8b)
- `ai code` — aider in ask mode by default, `-e/--edit` for code editing
- `ai review` — AI code review of branch, last commits, or specific commit
  - `--last [N]` review last N commits, `--commit SHA` specific commit
  - `--file FILE` review specific file, `--brief` short summary
  - `--lang LANG` response language, `--lang-all LANG` full response + thinking
- `ai models` — model manager (dynamic catalog from ollama.com, offline cache)
  - `list [FILTER]` show models filtered by RAM, `--all` show all
  - `install MODEL` / `rm MODEL` / `use MODEL` set default
  - `update` re-pull all installed, `info MODEL` show details, `prune` cleanup
  - `running` show loaded models
- `ai stop` — stop running models, `--server` to kill Ollama entirely
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
| Aider | `brew install aider` |
| OpenCode | `brew install opencode` |
| Pi | `brew install pi-coding-agent` |

**AI Models:**

```bash
ai models                           # browse available models
ai models install qwen3.5:9b       # install a model
ai models use qwen3.5:9b           # set as default
```

**AI Tools:**

| Tool | Purpose | Usage |
|------|---------|-------|
| `ai` | Local AI chat/review via Ollama | `ai "question"`, `ai review` |
| `ai code` | AI-assisted coding (aider + Ollama) | `ai code src/` |
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
| [nvim-keymaps.md](docs/nvim-keymaps.md) | Full Neovim keymaps reference |
| [leetcode.md](docs/leetcode.md) | LeetCode offline runner guide |

## Global Gitignore

`.gitignore_global` covers common artifacts for Java (jdtls), Scala (Metals/Bloop), Rust, Kotlin (Gradle), IDEs (IntelliJ, VS Code), and macOS.

## Uninstall

```bash
cd ~/dotfiles-mac
./install.sh unstow
```
