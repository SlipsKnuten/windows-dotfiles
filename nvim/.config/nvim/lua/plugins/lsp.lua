return {
  -- Keep signature help manual while using Noice's bordered documentation view
  {
    "folke/noice.nvim",
    opts = {
      lsp = {
        signature = {
          enabled = true,
          auto_open = { enabled = false },
        },
      },
      presets = {
        lsp_doc_border = true,
      },
    },
  },

  -- Quiet diagnostics: gutter signs only, no inlay hints
  {
    "neovim/nvim-lspconfig",
    opts = {
      diagnostics = {
        virtual_text = false,
        underline = false,
        signs = true,
        update_in_insert = false,
      },
      inlay_hints = {
        enabled = false,
      },
    },
  },
}
