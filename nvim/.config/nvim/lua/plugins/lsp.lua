return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      inlay_hints = {
        enabled = true, -- подсказки типов inline
      },
      diagnostics = {
        underline = true,
        update_in_insert = false,
        virtual_text = {
          spacing = 4,
          prefix = "●",
        },
        severity_sort = true,
      },
    },
  },
  {
    "hrsh7th/nvim-cmp",
    opts = function(_, opts)
      local cmp = require("cmp")
      opts.mapping = cmp.mapping.preset.insert({
        ["<C-Space>"] = cmp.mapping.complete(), -- вызвать автокомплит
        ["<CR>"] = cmp.mapping.confirm({ select = true }), -- подтвердить выбор
        ["<Tab>"] = cmp.mapping.select_next_item(), -- следующий вариант
        ["<S-Tab>"] = cmp.mapping.select_prev_item(), -- предыдущий вариант
        ["<C-d>"] = cmp.mapping.scroll_docs(4), -- скролл документации
        ["<C-u>"] = cmp.mapping.scroll_docs(-4),
      })
    end,
  },
}
