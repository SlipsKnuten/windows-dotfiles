-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here
vim.opt.relativenumber = false
vim.opt.wrap = true
vim.opt.linebreak = true
vim.opt.breakindent = true

local cargo_bin = vim.fn.expand("~/.cargo/bin")
if not (vim.env.PATH or ""):find(cargo_bin, 1, true) then
  vim.env.PATH = cargo_bin .. ":" .. (vim.env.PATH or "")
end

if vim.fn.has("wsl") == 1 then
  local copy = {
    "powershell.exe",
    "-NoLogo",
    "-NoProfile",
    "-Command",
    "Set-Clipboard -Value ([Console]::In.ReadToEnd())",
  }
  local paste = {
    "powershell.exe",
    "-NoLogo",
    "-NoProfile",
    "-Command",
    '$clip = Get-Clipboard -Raw; if ($null -ne $clip) { [Console]::Out.Write($clip.ToString().Replace("`r", "")) }',
  }

  vim.g.clipboard = {
    name = "WslClipboard",
    copy = {
      ["+"] = copy,
      ["*"] = copy,
    },
    paste = {
      ["+"] = paste,
      ["*"] = paste,
    },
    cache_enabled = 0,
  }
end

vim.opt.clipboard = "unnamedplus"
