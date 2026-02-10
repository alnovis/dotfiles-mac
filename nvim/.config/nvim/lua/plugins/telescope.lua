return {
  {
    "nvim-telescope/telescope.nvim",
    opts = {
      defaults = {
        layout_strategy = "horizontal",
        layout_config = {
          horizontal = {
            preview_width = 0.55,
          },
          width = 0.87,
          height = 0.80,
        },
        path_display = { "truncate" },
        file_ignore_patterns = {
          "node_modules",
          ".git/",
          "target/",
          ".metals/",
          ".bloop/",
          ".idea/",
        },
      },
    },
  },
}
