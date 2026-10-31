return {
  {
    "sindrets/diffview.nvim",
    cmd = { "DiffviewOpen", "DiffviewFileHistory" },
    keys = {
      { "<leader>gd", "<cmd>DiffviewOpen<cr>", desc = "Diff view" },
      { "<leader>gh", "<cmd>DiffviewFileHistory %<cr>", desc = "File history" },
    },
  },
  -- LazyVim's snacks picker binds the same keys (Git Diff / GitHub PRs / Git Status);
  -- drop them so ours (diffview here, gitsigns preview/stage hunk) win regardless of load order.
  {
    "folke/snacks.nvim",
    keys = {
      { "<leader>gd", false },
      { "<leader>gp", false },
      { "<leader>gs", false },
    },
  },
}
