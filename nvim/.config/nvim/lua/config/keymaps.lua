-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

---@diagnostic disable: undefined-global

local map = vim.keymap.set

-- Быстрое сохранение
map("n", "<C-s>", "<cmd>w<cr>", { desc = "Save" })
map("i", "<C-s>", "<esc><cmd>w<cr>", { desc = "Save" })
map("n", "<C-ы>", "<cmd>w<cr>", { desc = "Save (ru)" })
map("i", "<C-ы>", "<esc><cmd>w<cr>", { desc = "Save (ru)" })

-- Перемещение строк (Alt+j/k)
map("n", "<A-j>", "<cmd>m .+1<cr>==", { desc = "Move line down" })
map("n", "<A-k>", "<cmd>m .-2<cr>==", { desc = "Move line up" })
map("v", "<A-j>", ":m '>+1<cr>gv=gv", { desc = "Move selection down" })
map("v", "<A-k>", ":m '<-2<cr>gv=gv", { desc = "Move selection up" })
map("n", "<A-о>", "<cmd>m .+1<cr>==", { desc = "Move line down (ru)" })
map("n", "<A-л>", "<cmd>m .-2<cr>==", { desc = "Move line up (ru)" })
map("v", "<A-о>", ":m '>+1<cr>gv=gv", { desc = "Move selection down (ru)" })
map("v", "<A-л>", ":m '<-2<cr>gv=gv", { desc = "Move selection up (ru)" })

-- Быстрый выход из insert mode
map("i", "jk", "<esc>", { desc = "Exit insert mode" })
map("i", "ол", "<esc>", { desc = "Exit insert mode (ru)" })

-- Системный буфер обмена
map("v", "<leader>y", '"+y', { desc = "Copy to system clipboard" })
map("n", "<leader>p", '"+p', { desc = "Paste from system clipboard" })
map("n", "<leader>P", '"+P', { desc = "Paste before from clipboard" })
-- Кириллица
map("v", "<leader>н", '"+y', { desc = "Copy to clipboard (ru)" })
map("n", "<leader>з", '"+p', { desc = "Paste from clipboard (ru)" })
map("n", "<leader>З", '"+P', { desc = "Paste before from clipboard (ru)" })

-- Ctrl+Click — go to definition (как в IntelliJ)
vim.keymap.set("n", "<C-LeftMouse>", "<LeftMouse><cmd>lua vim.lsp.buf.definition()<CR>", { desc = "Go to definition" })

-- Ctrl+Alt+Click — find usages/references (как в IntelliJ)
vim.keymap.set("n", "<C-A-LeftMouse>", "<LeftMouse><cmd>lua vim.lsp.buf.references()<CR>", { desc = "Find usages" })

-- Навигация вперёд/назад (как Ctrl+Alt+Left/Right в IntelliJ)
vim.keymap.set("n", "<C-A-Left>", "<C-o>", { desc = "Navigate back" })
vim.keymap.set("n", "<C-A-Right>", "<C-i>", { desc = "Navigate forward" })

-- Альтернатива: Cmd+[ и Cmd+] (как в macOS)
vim.keymap.set("n", "<D-[>", "<C-o>", { desc = "Navigate back" })
vim.keymap.set("n", "<D-]>", "<C-i>", { desc = "Navigate forward" })

-- Terminal
map("n", "<leader>tf", function()
  vim.cmd("botright split | resize 15 | terminal")
  vim.cmd("startinsert")
end, { desc = "Horizontal terminal" })

map("n", "<leader>tv", function()
  vim.cmd("botright vsplit | terminal")
  vim.cmd("startinsert")
end, { desc = "Vertical terminal" })

map("n", "<leader>еа", function()
  vim.cmd("botright split | resize 15 | terminal")
  vim.cmd("startinsert")
end, { desc = "Horizontal terminal (ru)" })

map("n", "<leader>ем", function()
  vim.cmd("botright vsplit | terminal")
  vim.cmd("startinsert")
end, { desc = "Vertical terminal (ru)" })

map("t", "<Esc><Esc>", "<C-\\><C-n>", { desc = "Exit terminal mode" })

-- Scala / sbt
map("n", "<leader>sc", function()
  vim.cmd("botright split | resize 15 | terminal sbt compile")
  vim.cmd("startinsert")
end, { desc = "sbt compile" })

map("n", "<leader>sr", function()
  vim.cmd("botright split | resize 15 | terminal sbt run")
  vim.cmd("startinsert")
end, { desc = "sbt run" })

map("n", "<leader>st", function()
  vim.cmd("botright split | resize 15 | terminal sbt test")
  vim.cmd("startinsert")
end, { desc = "sbt test" })

map("n", "<leader>ыс", function()
  vim.cmd("botright split | resize 15 | terminal sbt compile")
  vim.cmd("startinsert")
end, { desc = "sbt compile (ru)" })

map("n", "<leader>ык", function()
  vim.cmd("botright split | resize 15 | terminal sbt run")
  vim.cmd("startinsert")
end, { desc = "sbt run (ru)" })

map("n", "<leader>ые", function()
  vim.cmd("botright split | resize 15 | terminal sbt test")
  vim.cmd("startinsert")
end, { desc = "sbt test (ru)" })

-- Rust / cargo
map("n", "<leader>rc", function()
  vim.cmd("botright split | resize 15 | terminal cargo build")
  vim.cmd("startinsert")
end, { desc = "cargo build" })

map("n", "<leader>rr", function()
  vim.cmd("botright split | resize 15 | terminal cargo run")
  vim.cmd("startinsert")
end, { desc = "cargo run" })

map("n", "<leader>rt", function()
  vim.cmd("botright split | resize 15 | terminal cargo test")
  vim.cmd("startinsert")
end, { desc = "cargo test" })

map("n", "<leader>кс", function()
  vim.cmd("botright split | resize 15 | terminal cargo build")
  vim.cmd("startinsert")
end, { desc = "cargo build (ru)" })

map("n", "<leader>кк", function()
  vim.cmd("botright split | resize 15 | terminal cargo run")
  vim.cmd("startinsert")
end, { desc = "cargo run (ru)" })

map("n", "<leader>ке", function()
  vim.cmd("botright split | resize 15 | terminal cargo test")
  vim.cmd("startinsert")
end, { desc = "cargo test (ru)" })

-- Java / Maven
map("n", "<leader>mc", function()
  vim.cmd("botright split | resize 15 | terminal mvn compile")
  vim.cmd("startinsert")
end, { desc = "mvn compile" })

map("n", "<leader>mr", function()
  vim.cmd("botright split | resize 15 | terminal mvn exec:java")
  vim.cmd("startinsert")
end, { desc = "mvn run" })

map("n", "<leader>mt", function()
  vim.cmd("botright split | resize 15 | terminal mvn test")
  vim.cmd("startinsert")
end, { desc = "mvn test" })

map("n", "<leader>mp", function()
  vim.cmd("botright split | resize 15 | terminal mvn package")
  vim.cmd("startinsert")
end, { desc = "mvn package" })

-- Кириллица Maven
map("n", "<leader>ьс", function()
  vim.cmd("botright split | resize 15 | terminal mvn compile")
  vim.cmd("startinsert")
end, { desc = "mvn compile (ru)" })

map("n", "<leader>ьк", function()
  vim.cmd("botright split | resize 15 | terminal mvn exec:java")
  vim.cmd("startinsert")
end, { desc = "mvn run (ru)" })

map("n", "<leader>ье", function()
  vim.cmd("botright split | resize 15 | terminal mvn test")
  vim.cmd("startinsert")
end, { desc = "mvn test (ru)" })

map("n", "<leader>ьз", function()
  vim.cmd("botright split | resize 15 | terminal mvn package")
  vim.cmd("startinsert")
end, { desc = "mvn package (ru)" })

-- Java / Gradle
map("n", "<leader>gc", function()
  vim.cmd("botright split | resize 15 | terminal gradle build")
  vim.cmd("startinsert")
end, { desc = "gradle build" })

map("n", "<leader>gr", function()
  vim.cmd("botright split | resize 15 | terminal gradle run")
  vim.cmd("startinsert")
end, { desc = "gradle run" })

map("n", "<leader>gt", function()
  vim.cmd("botright split | resize 15 | terminal gradle test")
  vim.cmd("startinsert")
end, { desc = "gradle test" })

-- Кириллица Gradle
map("n", "<leader>пс", function()
  vim.cmd("botright split | resize 15 | terminal gradle build")
  vim.cmd("startinsert")
end, { desc = "gradle build (ru)" })

map("n", "<leader>пк", function()
  vim.cmd("botright split | resize 15 | terminal gradle run")
  vim.cmd("startinsert")
end, { desc = "gradle run (ru)" })

map("n", "<leader>пе", function()
  vim.cmd("botright split | resize 15 | terminal gradle test")
  vim.cmd("startinsert")
end, { desc = "gradle test (ru)" })

-- Kotlin / Gradle
map("n", "<leader>kc", function()
  vim.cmd("botright split | resize 15 | terminal gradle compileKotlin")
  vim.cmd("startinsert")
end, { desc = "kotlin compile" })

map("n", "<leader>kr", function()
  vim.cmd("botright split | resize 15 | terminal gradle run")
  vim.cmd("startinsert")
end, { desc = "kotlin run" })

map("n", "<leader>kt", function()
  vim.cmd("botright split | resize 15 | terminal gradle test")
  vim.cmd("startinsert")
end, { desc = "kotlin test" })

-- Кириллица Kotlin
map("n", "<leader>лс", function()
  vim.cmd("botright split | resize 15 | terminal gradle compileKotlin")
  vim.cmd("startinsert")
end, { desc = "kotlin compile (ru)" })

map("n", "<leader>лк", function()
  vim.cmd("botright split | resize 15 | terminal gradle run")
  vim.cmd("startinsert")
end, { desc = "kotlin run (ru)" })

map("n", "<leader>ле", function()
  vim.cmd("botright split | resize 15 | terminal gradle test")
  vim.cmd("startinsert")
end, { desc = "kotlin test (ru)" })
