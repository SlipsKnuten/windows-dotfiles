return {
  "mg979/vim-visual-multi",
  event = "VeryLazy",
  init = function()
    vim.g.VM_maps = {
      ["Find Under"] = "<C-d>",        -- Select word under cursor
      ["Find Subword Under"] = "<C-d>", -- Also works in visual mode
      ["Add Cursor Down"] = "<C-j>",    -- Add cursor below
      ["Add Cursor Up"] = "<C-k>",      -- Add cursor above
    }
  end,
}
