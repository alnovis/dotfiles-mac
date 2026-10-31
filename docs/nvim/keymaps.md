# Neovim Keymaps Reference

LazyVim-based configuration with Kanagawa theme. Keymaps defined via `bimap()` in `keymaps.lua` (save, `jk`, move lines, clipboard, terminal, build, LeetCode) and the AI keys are duplicated for the Cyrillic layout; plugin keymaps (gitsigns, diffview, hardtime, LazyVim defaults) are not.

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
| `<leader>sr` | v | Search & replace in project (grug-far); in normal mode `<leader>sr` is sbt run |
| `<leader>sw` | n | Grep word under cursor (Snacks picker) |
| `<leader>sw` | v | Grep selection (Snacks picker) |
| `<leader>/` / `<leader>sg` | n | Live grep (Snacks picker) |
| `<leader>ff` | n | Find file (Snacks picker) |
| `<leader>fg` | n | Find git-tracked file (Snacks picker) |
| `<leader>fb` / `<leader>,` | n | Find buffer (Snacks picker) |
| `<leader>fr` | n | Recent files (Snacks picker) |

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
| `Ctrl+Space` | i | Trigger autocomplete / toggle docs |
| `Ctrl+n` / `Ctrl+p` | i | Next / previous completion item (also `Down` / `Up`) |
| `CR` | i | Confirm completion |
| `Ctrl+y` | i | Select and confirm |
| `Ctrl+e` | i | Cancel completion |
| `Tab` / `S-Tab` | i | Jump to next / previous snippet field |
| `Ctrl+f` / `Ctrl+b` | i | Scroll docs down / up |

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
| `y` / `x` / `p` | — | Copy / cut to Neo-tree clipboard, paste |
| `c` | — | Copy (prompts for destination) |
| `m` | — | Move (prompts for destination) |

### Buffers

| Key | Mode | Description |
|-----|------|-------------|
| `<S-h>` | n | Previous buffer |
| `<S-l>` | n | Next buffer |
| `<leader>bd` | n | Delete buffer |
| `<leader>bb` | n | Switch to other (alternate) buffer |

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
| `<leader>ghr` | n | Reset hunk (LazyVim default; `<leader>gr` is gradle run) |
| `<leader>gR` | n | Reset buffer |
| `<leader>gs` | n | Stage hunk |
| `<leader>gu` | n | Undo stage hunk |

LazyVim's full hunk set lives under `<leader>gh…` (`ghs`, `ghr`, `ghp`, `ghb`, …), so `<leader>gh` itself (file history, below) fires after the which-key timeout.

### Diffview & Lazygit

| Key | Mode | Description |
|-----|------|-------------|
| `<leader>gd` | n | Open diff view |
| `<leader>gh` | n | File history |
| `<leader>gg` | n | Open Lazygit |

## Build & Run

All build commands open a horizontal terminal split (15 lines).

Some of these keys replace LazyVim defaults: `<leader>sc` (Command History → use `<leader>:`), `<leader>st` (Todo → use `<leader>sT`), `<leader>sr` in normal mode (grug-far stays on visual `<leader>sr`), `<leader>gr` (gitsigns reset hunk → `<leader>ghr`).

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

### LeetCode

| Key | Cyrillic | Description |
|-----|----------|-------------|
| `<leader>lr` | `<leader>дк` | Run current solution with `lc-run` (see [docs/leetcode.md](../leetcode.md)) |

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
| `CR` (n) / `Ctrl+s` (i) | Send message |
| `#{buffer}`, `/buffer`, `/file` | Add a buffer / file to context |
| `@` | Tools |
| `ga` | Change adapter and model |
| `gx` | Clear chat |
| `gr` | Regenerate last response |
| `gd` | Show debug info |
| `q` | Stop the current request |
| `Ctrl+c` | Close chat |
| `?` | Show all chat keymaps |

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
