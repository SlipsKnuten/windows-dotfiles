-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

if vim.fn.has("wsl") == 1 then
  vim.api.nvim_create_autocmd("TextYankPost", {
    group = vim.api.nvim_create_augroup("wsl_clipboard_yank", { clear = true }),
    desc = "Sync unnamed yanks to the Windows clipboard",
    callback = function()
      local event = vim.v.event
      if event.operator ~= "y" or event.regname ~= "" then
        return
      end
      if not vim.o.clipboard:find("unnamedplus", 1, true) then
        return
      end

      vim.fn.setreg("+", event.regcontents, event.regtype)
    end,
  })
end
