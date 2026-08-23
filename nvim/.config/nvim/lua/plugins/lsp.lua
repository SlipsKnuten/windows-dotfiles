return {
  -- Tame the signature help popup
  {
    "folke/noice.nvim",
    opts = {
      lsp = {
        signature = { enabled = false },
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
