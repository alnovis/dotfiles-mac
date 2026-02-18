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
- Scala — Metals LSP, sbt build commands (`Space sc/sr/st`)
- Rust — rust-analyzer, cargo commands (`Space rc/rr/rt`)
- Java — jdtls, Maven/Gradle commands (`Space mc/mr/mt`, `Space gc/gr/gt`)
- Kotlin — kotlin-language-server, Gradle commands (`Space kc/kr/kt`)
- Docker — dockerfile LSP

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

- Japanesque color theme
- Tabbed interface (`Cmd+T/W`, `Cmd+1-5`)
- Split panes (`Cmd+D` vertical, `Cmd+Shift+D` horizontal)
- Copy/paste works on both English and Russian layouts

## Fish

- Git aliases (`gs`, `gl`, `gp`, `lg`)
- Editor aliases (`v`/`vim` → nvim, `idea`, `rr`)
- Docker aliases (`d`, `dc`, `dps`)
- Ollama aliases (`ai`, `ai-chat`, `ai-stop`)
- `less`/`PAGER` → `bat` (syntax highlighting)
- `trim` — trim whitespace from arguments
- `clipclean` — trim clipboard content in-place
- `clipcommit` — git commit from clipboard with confirmation (`-y` auto-confirm, `--amend`)

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

## Uninstall

```bash
cd ~/dotfiles-mac
./install.sh unstow
```
