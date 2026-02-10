return {
  {
    "nvim-neo-tree/neo-tree.nvim",
    opts = {
      filesystem = {
        filtered_items = {
          visible = true,
          hide_dotfiles = false,
          hide_gitignored = false,
        },
        follow_current_file = {
          enabled = true,
        },
        use_libuv_file_watcher = true,
      },
      window = {
        width = 35,
        mappings = {
          ["h"] = "close_node",
          ["l"] = "open",
          ["s"] = "open_vsplit",
          ["S"] = "open_split",
          ["e"] = "expand_all_nodes",
          ["W"] = "close_all_nodes",
        },
      },
      default_component_configs = {
        indent = {
          with_expanders = true,
        },
        git_status = {
          symbols = {
            added = "+",
            modified = "~",
            deleted = "✖",
            renamed = "→",
            untracked = "?",
            ignored = "◌",
            unstaged = "○",
            staged = "●",
            conflict = "!",
          },
        },
      },
    },
  },
}

