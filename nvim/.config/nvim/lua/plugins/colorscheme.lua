return {
  {
    "rebelot/kanagawa.nvim",
    opts = {
      compile = true,
      commentStyle = { italic = true },
      keywordStyle = { italic = true },
      statementStyle = { bold = true },
      dimInactive = true, -- затемнять неактивные окна
    },
  },
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "kanagawa-wave",
    },
  },
}
