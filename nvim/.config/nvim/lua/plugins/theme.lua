local omarchy_theme = vim.fn.expand("~/.config/omarchy/current/theme/neovim.lua")
if vim.fn.filereadable(omarchy_theme) == 1 then
	return dofile(omarchy_theme)
end

return {
	{ "catppuccin/nvim", name = "catppuccin", priority = 1000 },
	{ "LazyVim/LazyVim", opts = { colorscheme = "catppuccin" } },
}
