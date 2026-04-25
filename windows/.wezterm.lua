local wezterm = require 'wezterm'
local config = wezterm.config_builder()

config.default_domain = 'WSL:Ubuntu-24.04'

config.color_scheme = 'One Dark (Gogh)'

config.font = wezterm.font('Hack Nerd Font', { weight = 'Regular' })

config.keys = {
  { key = 'v', mods = 'CTRL', action = wezterm.action.PasteFrom 'Clipboard' },
}

return config