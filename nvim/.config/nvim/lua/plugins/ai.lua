return {
  {
    "David-Kunz/gen.nvim",
    opts = {
      model = "deepseek-coder-v2:16b",
      display_mode = "horizontal-split",
      show_prompt = true,
      show_model = true,
      no_auto_close = true,
    },
    keys = {
      { "<leader>ag", ":Gen<cr>", mode = { "n", "v" }, desc = "AI menu" },
      { "<leader>ac", ":Gen Chat<cr>", mode = { "n", "v" }, desc = "AI chat" },
      -- Кириллица
      { "<leader>фп", ":Gen<cr>", mode = { "n", "v" }, desc = "AI menu (ru)" },
      { "<leader>фс", ":Gen Chat<cr>", mode = { "n", "v" }, desc = "AI chat (ru)" },
    },
  },
}