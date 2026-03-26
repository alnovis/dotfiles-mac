return {
  {
    "rebelot/kanagawa.nvim",
    opts = {
      compile = true,
      commentStyle = { italic = true },
      keywordStyle = { italic = true },
      statementStyle = { bold = true },
      dimInactive = true,
      overrides = function(colors)
        return {
          Visual = { bg = "#54546D" },
        }
      end,
    },
  },
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "kanagawa-wave",
    },
  },
}
