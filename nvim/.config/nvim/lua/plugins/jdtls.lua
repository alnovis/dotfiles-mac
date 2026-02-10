return {
  {
    "mfussenegger/nvim-jdtls",
    opts = {
      jdtls = function(opts)
        opts.settings = {
          java = {
            project = {
              referencedLibraries = {},
            },
          },
        }
        -- Хранить данные проекта в ~/.cache вместо папки проекта
        local project_name = vim.fn.fnamemodify(vim.fn.getcwd(), ":p:h:t")
        opts.cmd = opts.cmd or {}
        table.insert(opts.cmd, "-data")
        table.insert(opts.cmd, vim.fn.expand("~/.cache/jdtls/workspace/") .. project_name)
        return opts
      end,
    },
  },
}