return {
  "folke/snacks.nvim",
  keys = {
    { "<leader>pp", function() Snacks.picker.projects() end, desc = "Switch Project" },
    { "<C-p>", function() Snacks.picker.projects() end, desc = "Switch Project" },
  },
}
