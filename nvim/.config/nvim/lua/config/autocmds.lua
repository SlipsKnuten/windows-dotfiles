-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

-- `:q` typed while the neo-tree sidebar is focused would only close the sidebar;
-- make it quit Neovim instead (still prompts about unsaved buffers)
vim.api.nvim_create_autocmd("FileType", {
  pattern = "neo-tree",
  callback = function(args)
    vim.keymap.set("ca", "q", function()
      return vim.fn.getcmdtype() == ":" and vim.fn.getcmdline() == "q" and "qa" or "q"
    end, { buffer = args.buf, expr = true })
  end,
})
