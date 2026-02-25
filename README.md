# Dotfiles (macOS)

Development environment configuration for MacBook Pro M4 Max, optimized for Scala, Rust, Java, and Kotlin development.

## Components

| Component | Description |
|-----------|-------------|
| **nvim** | Neovim (LazyVim) with LSP for Scala, Rust, Java, Kotlin |
| **kitty** | Kitty terminal with Japanesque theme |
| **fish** | Fish shell with dev aliases and SDKMAN integration |

## Quick Install

```bash
# Install dependencies
brew install neovim fish stow lazygit bat jq
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

**Theme:** Kanagawa Dragon

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
- gen.nvim — local AI via Ollama (`Space ac/ag`)
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
- Ollama: `ai` (deepseek-coder), `ai-chat` (llama3.1), `ai-stop`
- Pager: `less`/`PAGER` → `bat`

**Functions:**
- `trim` — trim leading/trailing whitespace per line (args or stdin)
- `clipclean` — dedent and trim clipboard (removes common leading indentation)
- `clipcommit` — git commit using clipboard as message
  - `-y/--yes` skip confirmation, `-a/--amend` amend previous commit
  - `-p/--push` push after commit, `-d/--diff` show full diff before committing
  - `-e/--edit` edit message in nvim, `--no-color` disable colored stat output
  - `-h/--help` show usage — warns about unstaged changes

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

**AI Models:**

```bash
ollama pull deepseek-coder-v2:16b   # coding assistant
ollama pull llama3.1:8b              # general chat
```

## macOS Apps

- [Rectangle](https://rectangleapp.com/) — window management
- [OrbStack](https://orbstack.dev/) — Docker runtime
- [IntelliJ IDEA CE](https://www.jetbrains.com/idea/) — Scala/Java/Kotlin IDE
- [RustRover](https://www.jetbrains.com/rust/) — Rust IDE

## Global Gitignore

`.gitignore_global` covers common artifacts for Java (jdtls), Scala (Metals/Bloop), Rust, Kotlin (Gradle), IDEs (IntelliJ, VS Code), and macOS.

## Uninstall

```bash
cd ~/dotfiles-mac
./install.sh unstow
```
