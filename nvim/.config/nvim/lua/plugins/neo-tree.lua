local explorer_width = 30

return {
  {
    "nvim-neo-tree/neo-tree.nvim",
    opts = {
      window = {
        width = function()
          return explorer_width
        end,
      },
      event_handlers = {
        {
          event = "neo_tree_window_before_close",
          handler = function(args)
            if vim.api.nvim_win_is_valid(args.winid) then
              explorer_width = vim.api.nvim_win_get_width(args.winid)
            end
          end,
        },
      },
      filesystem = {
        filtered_items = {
          hide_dotfiles = false,
          hide_gitignored = false,
        },
      },
    },
  },
}
