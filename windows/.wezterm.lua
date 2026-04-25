local wezterm = require 'wezterm'
local config = wezterm.config_builder()

-- Pick whichever WSL Ubuntu distro is registered, regardless of version suffix.
local function wsl_ubuntu()
  for _, d in ipairs(wezterm.default_wsl_domains()) do
    if d.name:match("Ubuntu") then return d.name end
  end
end
config.default_domain = wsl_ubuntu() or 'local'

config.font = wezterm.font('Hack Nerd Font', { weight = 'Regular' })

-- Canonical Atom One Dark palette (not the muddy "Gogh" variant).
config.colors = {
  background = '#282c34',
  foreground = '#abb2bf',
  cursor_bg  = '#528bff',
  cursor_fg  = '#282c34',
  cursor_border    = '#528bff',
  selection_bg     = '#3e4451',
  selection_fg     = '#abb2bf',
  ansi    = { '#282c34', '#e06c75', '#98c379', '#e5c07b', '#61afef', '#c678dd', '#56b6c2', '#abb2bf' },
  brights = { '#5c6370', '#e06c75', '#98c379', '#e5c07b', '#61afef', '#c678dd', '#56b6c2', '#ffffff' },
}

config.keys = {
  { key = 'v', mods = 'CTRL', action = wezterm.action.PasteFrom 'Clipboard' },
}

return config