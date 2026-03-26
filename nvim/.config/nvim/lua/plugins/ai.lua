-- Ensure Ollama is running before AI commands
local function ensure_ollama()
  if vim.fn.executable("ollama") ~= 1 then
    return
  end
  if os.execute("pgrep -q ollama") == 0 then
    return
  end

  vim.notify("Starting Ollama...", vim.log.levels.INFO)
  vim.fn.jobstart({ "ollama", "serve" }, { detach = true })

  local attempts = 0
  local timer = vim.uv.new_timer()
  timer:start(500, 500, vim.schedule_wrap(function()
    attempts = attempts + 1
    if os.execute("curl -s --connect-timeout 1 http://localhost:11434/ >/dev/null 2>&1") == 0 then
      timer:stop()
      timer:close()
      vim.notify("Ollama ready", vim.log.levels.INFO)
    elseif attempts >= 20 then
      timer:stop()
      timer:close()
      vim.notify("Ollama failed to start", vim.log.levels.ERROR)
    end
  end))
end

return {
  {
    "olimorris/codecompanion.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-treesitter/nvim-treesitter",
    },
    init = function()
      ensure_ollama()
    end,
    opts = {
      adapters = {
        ollama = function()
          return require("codecompanion.adapters").extend("ollama", {
            schema = {
              model = {
                default = "qwen3.5:9b",
              },
            },
          })
        end,
      },
      strategies = {
        chat = { adapter = "ollama" },
        inline = { adapter = "ollama" },
        agent = { adapter = "ollama" },
      },
      display = {
        chat = {
          window = {
            layout = "vertical",
            width = 0.4,
          },
        },
      },
    },
    keys = {
      { "<leader>ac", "<cmd>CodeCompanionChat Toggle<cr>", mode = "n", desc = "AI chat" },
      { "<leader>ac", ":'<,'>CodeCompanionChat Toggle<cr>", mode = "v", desc = "AI chat (visual)" },
      { "<leader>ag", "<cmd>CodeCompanionActions<cr>", mode = "n", desc = "AI actions" },
      { "<leader>ag", ":'<,'>CodeCompanionActions<cr>", mode = "v", desc = "AI actions (visual)" },
      { "<leader>ai", "<cmd>CodeCompanion<cr>", mode = "n", desc = "AI inline" },
      { "<leader>ai", ":'<,'>CodeCompanion<cr>", mode = "v", desc = "AI inline (visual)" },
      -- Кириллица
      { "<leader>фс", "<cmd>CodeCompanionChat Toggle<cr>", mode = "n", desc = "AI chat (ru)" },
      { "<leader>фс", ":'<,'>CodeCompanionChat Toggle<cr>", mode = "v", desc = "AI chat (ru, visual)" },
      { "<leader>фп", "<cmd>CodeCompanionActions<cr>", mode = "n", desc = "AI actions (ru)" },
      { "<leader>фп", ":'<,'>CodeCompanionActions<cr>", mode = "v", desc = "AI actions (ru, visual)" },
      { "<leader>фш", "<cmd>CodeCompanion<cr>", mode = "n", desc = "AI inline (ru)" },
      { "<leader>фш", ":'<,'>CodeCompanion<cr>", mode = "v", desc = "AI inline (ru, visual)" },
    },
  },
}
