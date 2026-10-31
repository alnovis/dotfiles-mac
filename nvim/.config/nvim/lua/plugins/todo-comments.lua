return {
  {
    "folke/todo-comments.nvim",
    -- <leader>st is sbt test (keymaps.lua); todo-comments loads on file open and would
    -- take the key over when nvim starts without a file. Todo picker stays on <leader>sT.
    keys = {
      { "<leader>st", false },
    },
  },
}
