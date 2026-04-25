-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

-- Super+j/k to move 5 lines at a time
vim.keymap.set({ "n", "v" }, "<D-j>", "5j", { desc = "Move down 5 lines" })
vim.keymap.set({ "n", "v" }, "<D-k>", "5k", { desc = "Move up 5 lines" })

-- Super+h/l to go to beginning/end of line
vim.keymap.set({ "n", "v" }, "<D-h>", "^", { desc = "Go to beginning of line" })
vim.keymap.set({ "n", "v" }, "<D-l>", "$", { desc = "Go to end of line" })
vim.keymap.set("i", "<D-h>", "<Home>", { desc = "Go to beginning of line" })
vim.keymap.set("i", "<D-l>", "<End>", { desc = "Go to end of line" })

-- Swap i and a: i inserts after cursor, a inserts before
vim.keymap.set("n", "i", "a", { noremap = true, desc = "Insert after cursor" })
vim.keymap.set("n", "a", "i", { noremap = true, desc = "Insert before cursor" })

-- Prevent cursor from jumping back when leaving insert mode
vim.api.nvim_create_autocmd("InsertLeave", {
  callback = function()
    local cur = vim.api.nvim_win_get_cursor(0)
    local line = vim.api.nvim_get_current_line()
    if cur[2] > 0 and cur[2] < #line then
      vim.api.nvim_win_set_cursor(0, { cur[1], cur[2] + 1 })
    end
  end,
  desc = "Prevent cursor from moving back on insert leave",
})
