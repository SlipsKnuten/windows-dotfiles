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
  local linux_paths = {}
  local seen_paths = {}
  for _, path in ipairs(vim.split(vim.env.PATH or "", ":", { plain = true })) do
    if path ~= "" and not path:find("^/mnt/") and not seen_paths[path] then
      table.insert(linux_paths, path)
      seen_paths[path] = true
    end
  end
  vim.env.PATH = table.concat(linux_paths, ":")

  if vim.fn.executable("wl-copy") == 0 or vim.fn.executable("wl-paste") == 0 then
    local system32 = "/mnt/c/Windows/System32"
    local copy = { system32 .. "/clip.exe" }
    local paste = {
      system32 .. "/WindowsPowerShell/v1.0/powershell.exe",
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
end

vim.opt.clipboard = "unnamedplus"
