-- Open project grep (Alt+s, Space /, Space s g) fullscreen.
return {
  "folke/snacks.nvim",
  opts = {
    picker = {
      sources = {
        grep = {
          layout = { fullscreen = true },
        },
      },
    },
  },
}
