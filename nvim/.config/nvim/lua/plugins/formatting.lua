return {
  {
    "stevearc/conform.nvim",
    opts = {
      format_on_save = {
        timeout_ms = 3000,
        lsp_format = "fallback",
      },
      formatters_by_ft = {
        python = { "ruff_format" },
        yaml = { "prettier" },
      },
    },
  },
}
