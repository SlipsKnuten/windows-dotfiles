-- Compact bufferline so as many buffers as possible fit on screen
return {
  "akinsho/bufferline.nvim",
  opts = {
    options = {
      tab_size = 0,
      truncate_names = false, -- always show the full filename
      show_buffer_close_icons = false,
      show_close_icon = false,
      show_buffer_icons = false,
      diagnostics = false,
      separator_style = { "", "" },
      indicator = { style = "none" },
      numbers = "ordinal", -- matches the Alt+1-9 BufferLineGoToBuffer keymaps
    },
  },
}
