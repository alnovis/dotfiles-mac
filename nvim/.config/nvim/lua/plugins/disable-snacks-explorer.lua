return {
  {
    "folke/snacks.nvim",
    opts = {
      explorer = { enabled = false },
    },
    -- its keys would still point at the disabled explorer; <leader>e is Neo-tree (neo-tree.lua)
    keys = {
      { "<leader>e", false },
      { "<leader>E", false },
      { "<leader>fe", false },
      { "<leader>fE", false },
    },
  },
}