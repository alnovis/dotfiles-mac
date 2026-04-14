-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

---@diagnostic disable: undefined-global

local map = vim.keymap.set

-- English → Cyrillic key mapping (ЙЦУКЕН layout)
local en_to_ru = {
  a = "ф", b = "и", c = "с", d = "в", e = "у", f = "а", g = "п",
  h = "р", i = "ш", j = "о", k = "л", l = "д", m = "ь", n = "т",
  o = "щ", p = "з", q = "й", r = "к", s = "ы", t = "е", u = "г",
  v = "м", w = "ц", x = "ч", y = "н", z = "я",
  A = "Ф", B = "И", C = "С", D = "В", E = "У", F = "А", G = "П",
  H = "Р", I = "Ш", J = "О", K = "Л", L = "Д", M = "Ь", N = "Т",
  O = "Щ", P = "З", Q = "Й", R = "К", S = "Ы", T = "Е", U = "Г",
  V = "М", W = "Ц", X = "Ч", Y = "Н", Z = "Я",
}

--- Translate key sequence to Cyrillic equivalent
local function to_ru(key)
  -- <leader>chars → <leader>cyrillic
  local rest = key:match("^<leader>(.+)$")
  if rest then
    return "<leader>" .. rest:gsub("%a", function(c) return en_to_ru[c] or c end)
  end
  -- <Mod-char> → <Mod-cyrillic> (single char after last -)
  local pre, ch = key:match("^(.+%-)(%a)>$")
  if pre then
    return pre .. (en_to_ru[ch] or ch) .. ">"
  end
  -- bare chars (jk → ол), skip if contains < (special keys)
  if not key:find("<") then
    return key:gsub("%a", function(c) return en_to_ru[c] or c end)
  end
  return key
end

--- Map key with automatic Cyrillic duplicate
local function bimap(mode, lhs, rhs, opts)
  opts = opts or {}
  map(mode, lhs, rhs, opts)
  local ru = to_ru(lhs)
  if ru ~= lhs then
    map(mode, ru, rhs, vim.tbl_extend("force", opts, { desc = (opts.desc or "") .. " (ru)" }))
  end
end

--- Run shell command in a horizontal terminal split
local function term(cmd)
  return function()
    vim.cmd("botright split | resize 15 | terminal " .. cmd)
    vim.cmd("startinsert")
  end
end

-- Быстрое сохранение
bimap("n", "<C-s>", "<cmd>w<cr>", { desc = "Save" })
bimap("i", "<C-s>", "<esc><cmd>w<cr>", { desc = "Save" })

-- Перемещение строк (Alt+j/k)
bimap("n", "<A-j>", "<cmd>m .+1<cr>==", { desc = "Move line down" })
bimap("n", "<A-k>", "<cmd>m .-2<cr>==", { desc = "Move line up" })
bimap("v", "<A-j>", ":m '>+1<cr>gv=gv", { desc = "Move selection down" })
bimap("v", "<A-k>", ":m '<-2<cr>gv=gv", { desc = "Move selection up" })

-- Быстрый выход из insert mode
bimap("i", "jk", "<esc>", { desc = "Exit insert mode" })

-- Системный буфер обмена
bimap("v", "<leader>y", '"+y', { desc = "Copy to system clipboard" })
bimap("n", "<leader>p", '"+p', { desc = "Paste from system clipboard" })
bimap("n", "<leader>P", '"+P', { desc = "Paste before from clipboard" })

-- Ctrl+Click — go to definition (как в IntelliJ)
map("n", "<C-LeftMouse>", "<LeftMouse><cmd>lua vim.lsp.buf.definition()<CR>", { desc = "Go to definition" })

-- Ctrl+Alt+Click — find usages/references (как в IntelliJ)
map("n", "<C-A-LeftMouse>", "<LeftMouse><cmd>lua vim.lsp.buf.references()<CR>", { desc = "Find usages" })

-- Навигация вперёд/назад (как Ctrl+Alt+Left/Right в IntelliJ)
map("n", "<C-A-Left>", "<C-o>", { desc = "Navigate back" })
map("n", "<C-A-Right>", "<C-i>", { desc = "Navigate forward" })

-- Альтернатива: Cmd+[ и Cmd+] (как в macOS)
map("n", "<D-[>", "<C-o>", { desc = "Navigate back" })
map("n", "<D-]>", "<C-i>", { desc = "Navigate forward" })

-- Terminal
bimap("n", "<leader>tf", function()
  vim.cmd("botright split | resize 15 | terminal")
  vim.cmd("startinsert")
end, { desc = "Horizontal terminal" })

bimap("n", "<leader>tv", function()
  vim.cmd("botright vsplit | terminal")
  vim.cmd("startinsert")
end, { desc = "Vertical terminal" })

map("t", "<Esc><Esc>", "<C-\\><C-n>", { desc = "Exit terminal mode" })

-- Scala / sbt
bimap("n", "<leader>sc", term("sbt compile"), { desc = "sbt compile" })
bimap("n", "<leader>sr", term("sbt run"), { desc = "sbt run" })
bimap("n", "<leader>st", term("sbt test"), { desc = "sbt test" })

-- Rust / cargo
bimap("n", "<leader>rc", term("cargo build"), { desc = "cargo build" })
bimap("n", "<leader>rr", term("cargo run"), { desc = "cargo run" })
bimap("n", "<leader>rt", term("cargo test"), { desc = "cargo test" })

-- Java / Maven
bimap("n", "<leader>mc", term("mvn compile"), { desc = "mvn compile" })
bimap("n", "<leader>mr", term("mvn exec:java"), { desc = "mvn run" })
bimap("n", "<leader>mt", term("mvn test"), { desc = "mvn test" })
bimap("n", "<leader>mp", term("mvn package"), { desc = "mvn package" })

-- Java / Gradle
bimap("n", "<leader>gc", term("gradle build"), { desc = "gradle build" })
bimap("n", "<leader>gr", term("gradle run"), { desc = "gradle run" })
bimap("n", "<leader>gt", term("gradle test"), { desc = "gradle test" })

-- Kotlin / Gradle
bimap("n", "<leader>kc", term("gradle compileKotlin"), { desc = "kotlin compile" })
bimap("n", "<leader>kr", term("gradle run"), { desc = "kotlin run" })
bimap("n", "<leader>kt", term("gradle test"), { desc = "kotlin test" })

-- LeetCode
bimap("n", "<leader>lr", function()
  local file = vim.fn.expand("%:p")
  vim.cmd("botright split | resize 15 | terminal lc-run " .. file)
  vim.cmd("startinsert")
end, { desc = "LeetCode run tests" })
