return {
  {
    "stevearc/conform.nvim",
    opts = {
      formatters_by_ft = {
        scala = { "scalafmt" },
        rust = { "rustfmt" },
        kotlin = { "ktlint" },
        java = { "google-java-format" },
      },
      format_on_save = {
        timeout_ms = 3000,
        lsp_fallback = true,
      },
    },
  },
}