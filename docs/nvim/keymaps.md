# Neovim Keymaps Reference

LazyVim-based configuration with Kanagawa theme. All custom keymaps are duplicated for Cyrillic layout.

> `<leader>` = `Space`

## Navigation

| Key | Mode | Description |
|-----|------|-------------|
| `h/j/k/l` | n | Left / Down / Up / Right |
| `w` | n | Next word |
| `b` | n | Previous word |
| `e` | n | End of word |
| `0` | n | Start of line |
| `$` | n | End of line |
| `^` | n | First non-blank character |
| `gg` | n | Go to first line |
| `G` | n | Go to last line |
| `{` / `}` | n | Previous / next paragraph |
| `Ctrl+d` | n | Half page down |
| `Ctrl+u` | n | Half page up |
| `%` | n | Jump to matching bracket |
| `Ctrl+o` | n | Jump back |
| `Ctrl+i` | n | Jump forward |
| `Ctrl+Click` | n | Go to definition (LSP) |
| `Ctrl+Alt+Click` | n | Find usages (LSP) |
| `Ctrl+Alt+Left` | n | Navigate back |
| `Ctrl+Alt+Right` | n | Navigate forward |
| `Cmd+[` / `Cmd+]` | n | Navigate back / forward (macOS) |

## Selection

| Key | Mode | Description |
|-----|------|-------------|
| `v` | n | Visual character mode |
| `V` | n | Visual line mode |
| `Ctrl+v` | n | Visual block mode |
| `viw` | n | Select word under cursor |
| `vi"` | n | Select inside quotes |
| `vi(` | n | Select inside parentheses |
| `vi{` | n | Select inside braces |
| `vit` | n | Select inside tag |
| `vap` | n | Select paragraph |
| `ggVG` | n | Select entire file |
| `j` / `k` | v | Extend selection down / up |
| `o` | v | Toggle cursor to other end of selection |

## Editing

| Key | Mode | Description |
|-----|------|-------------|
| `i` / `a` | n | Insert before / after cursor |
| `I` / `A` | n | Insert at start / end of line |
| `o` / `O` | n | New line below / above |
| `jk` | i | Exit insert mode (also `ол` Cyrillic) |
| `Ctrl+s` | n, i | Save file (also `Ctrl+ы` Cyrillic) |
| `u` | n | Undo |
| `Ctrl+r` | n | Redo |
| `.` | n | Repeat last change |
| `dd` | n | Delete line |
| `yy` | n | Copy line |
| `p` / `P` | n | Paste after / before |
| `yyp` | n | Duplicate line |
| `yap` + `}p` | n | Duplicate paragraph |
| `V` + select + `y` + `p` | v | Duplicate block |
| `cc` | n | Change entire line |
| `ciw` | n | Change word |
| `ci"` | n | Change inside quotes |
| `>>` / `<<` | n | Indent / unindent |
| `>` / `<` | v | Indent / unindent selection |
| `Alt+j` | n, v | Move line(s) down |
| `Alt+k` | n, v | Move line(s) up |
| `~` | n | Toggle case |
| `gU` / `gu` | v | Uppercase / lowercase selection |

## Clipboard

| Key | Mode | Description |
|-----|------|-------------|
| `<leader>y` | v | Copy to system clipboard |
| `<leader>p` | n | Paste from system clipboard |
| `<leader>P` | n | Paste before from clipboard |

## Search & Replace

| Key | Mode | Description |
|-----|------|-------------|
| `/` | n | Search forward |
| `?` | n | Search backward |
| `n` / `N` | n | Next / previous match |
| `*` | n | Search word under cursor |
| `<leader>sr` | n | Open Spectre (project search & replace) |
| `<leader>sw` | n | Search current word (Spectre) |
| `<leader>sw` | v | Search selection (Spectre) |
| `<leader>ff` | n | Find file (Telescope) |
| `<leader>fg` | n | Live grep (Telescope) |
| `<leader>fb` | n | Find buffer (Telescope) |
| `<leader>fr` | n | Recent files (Telescope) |

## LSP (Language Server)

| Key | Mode | Description |
|-----|------|-------------|
| `gd` | n | Go to definition |
| `gr` | n | Find references |
| `gI` | n | Go to implementation |
| `gy` | n | Go to type definition |
| `K` | n | Hover documentation |
| `gK` | n | Signature help |
| `<leader>ca` | n | Code action |
| `<leader>cr` | n | Rename symbol |
| `<leader>cd` | n | Line diagnostics |
| `]d` / `[d` | n | Next / previous diagnostic |
| `Ctrl+Space` | i | Trigger autocomplete |
| `CR` | i | Confirm completion |
| `Tab` / `S-Tab` | i | Next / previous completion item |
| `Ctrl+d` / `Ctrl+u` | i | Scroll docs down / up |

## File Management

### Neo-tree (`<leader>e`)

| Key | Mode | Description |
|-----|------|-------------|
| `<leader>e` | n | Toggle file tree |
| `l` | — | Open file |
| `h` | — | Close node |
| `s` | — | Open in vertical split |
| `S` | — | Open in horizontal split |
| `e` | — | Expand all nodes |
| `W` | — | Close all nodes |
| `a` | — | Add file/directory |
| `d` | — | Delete |
| `r` | — | Rename |
| `c` / `p` | — | Copy / paste |
| `m` | — | Move |

### Buffers

| Key | Mode | Description |
|-----|------|-------------|
| `<S-h>` | n | Previous buffer |
| `<S-l>` | n | Next buffer |
| `<leader>bd` | n | Delete buffer |
| `<leader>bb` | n | Switch buffer (Telescope) |

## Windows & Splits

| Key | Mode | Description |
|-----|------|-------------|
| `<C-h/j/k/l>` | n | Navigate between splits |
| `<leader>-` | n | Horizontal split |
| `<leader>\|` | n | Vertical split |
| `<C-Up/Down/Left/Right>` | n | Resize splits |

## Terminal

| Key | Mode | Description |
|-----|------|-------------|
| `<leader>tf` | n | Horizontal terminal (split) |
| `<leader>tv` | n | Vertical terminal (vsplit) |
| `Esc Esc` | t | Exit terminal mode |

## Git

### Gitsigns

| Key | Mode | Description |
|-----|------|-------------|
| `]h` / `[h` | n | Next / previous hunk |
| `<leader>gp` | n | Preview hunk |
| `<leader>gr` | n | Reset hunk |
| `<leader>gR` | n | Reset buffer |
| `<leader>gs` | n | Stage hunk |
| `<leader>gu` | n | Undo stage hunk |

### Diffview & Lazygit

| Key | Mode | Description |
|-----|------|-------------|
| `<leader>gd` | n | Open diff view |
| `<leader>gh` | n | File history |
| `<leader>gg` | n | Open Lazygit |

## Build & Run

All build commands open a horizontal terminal split (15 lines).

### Scala (sbt)

| Key | Cyrillic | Description |
|-----|----------|-------------|
| `<leader>sc` | `<leader>ыс` | sbt compile |
| `<leader>sr` | `<leader>ык` | sbt run |
| `<leader>st` | `<leader>ые` | sbt test |

### Rust (cargo)

| Key | Cyrillic | Description |
|-----|----------|-------------|
| `<leader>rc` | `<leader>кс` | cargo build |
| `<leader>rr` | `<leader>кк` | cargo run |
| `<leader>rt` | `<leader>ке` | cargo test |

### Java (Maven)

| Key | Cyrillic | Description |
|-----|----------|-------------|
| `<leader>mc` | `<leader>ьс` | mvn compile |
| `<leader>mr` | `<leader>ьк` | mvn exec:java |
| `<leader>mt` | `<leader>ье` | mvn test |
| `<leader>mp` | `<leader>ьз` | mvn package |

### Java/Kotlin (Gradle)

| Key | Cyrillic | Description |
|-----|----------|-------------|
| `<leader>gc` | `<leader>пс` | gradle build |
| `<leader>gr` | `<leader>пк` | gradle run |
| `<leader>gt` | `<leader>пе` | gradle test |

### Kotlin (Gradle)

| Key | Cyrillic | Description |
|-----|----------|-------------|
| `<leader>kc` | `<leader>лс` | gradle compileKotlin |
| `<leader>kr` | `<leader>лк` | gradle run |
| `<leader>kt` | `<leader>ле` | gradle test |

## AI (CodeCompanion + Ollama)

Model: `qwen3.5:9b`. Auto-starts Ollama on first use.

| Key | Cyrillic | Mode | Description |
|-----|----------|------|-------------|
| `<leader>ac` | `<leader>фс` | n | Open AI chat |
| `<leader>ac` | `<leader>фс` | v | Chat with selected code |
| `<leader>ag` | `<leader>фп` | n, v | AI actions menu (Explain, Refactor, Fix, Tests) |
| `<leader>ai` | `<leader>фш` | n, v | AI inline prompt |

### Inside Chat

| Key | Description |
|-----|-------------|
| `@` | Add file/buffer to context |
| `/` | Slash commands (model, clear, help) |
| `gd` | Delete message |
| `q` | Close chat |

## Formatting

Auto-format on save (3s timeout, LSP fallback).

| Language | Formatter |
|----------|-----------|
| Scala | scalafmt |
| Rust | rustfmt |
| Kotlin | ktlint |
| Java | google-java-format |

## Other

| Key | Mode | Description |
|-----|------|-------------|
| `<leader>uh` | n | Toggle Hardtime (motion trainer) |
| `<leader>l` | n | Open Lazy (plugin manager) |
| `<leader>qq` | n | Quit all |
