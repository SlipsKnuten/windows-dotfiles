-- Side-by-side full-file diff preview for the git diff picker (<leader>gd / <leader>gD).
-- The whole file is rendered with delta and the preview is scrolled to the selected hunk.
local function full_file_diff(ctx)
  local item, picker = ctx.item, ctx.picker
  if not item.file then
    return require("snacks.picker.preview").diff(ctx)
  end

  local git = { "git", "-C", picker:cwd(), "diff", "--no-color", "--no-ext-diff", "-U100000" }
  if picker.opts.staged then
    table.insert(git, "--cached")
  elseif picker.opts.base then
    vim.list_extend(git, { "--merge-base", picker.opts.base })
  else
    table.insert(git, "HEAD")
  end
  vim.list_extend(git, { "--", item.file })
  local diff = vim.fn.system(git)

  local out = vim.fn.system({
    "delta",
    "--" .. vim.o.background,
    "--side-by-side",
    "--file-style=omit",
    "--hunk-header-style=omit",
    "--width=" .. vim.api.nvim_win_get_width(ctx.win),
  }, diff)
  local lines = vim.split(out, "\n", { plain = true })

  -- find the first row whose right-hand (new file) line number reaches the hunk start
  local target, row = item.pos and item.pos[1] or 1, 1
  for i, line in ipairs(lines) do
    local plain = line:gsub("\27%[[%d;]*m", "")
    local n = tonumber(plain:match("^│%s*%d*%s*│.-│%s*(%d+)%s*│"))
    if n and n >= target then
      row = i
      break
    end
  end

  local buf = ctx.preview:scratch()
  vim.api.nvim_chan_send(vim.api.nvim_open_term(buf, {}), table.concat(lines, "\r\n"))

  -- the terminal renders asynchronously, so wait for the target row before scrolling
  local tries = 0
  local function scroll()
    tries = tries + 1
    if not (vim.api.nvim_win_is_valid(ctx.win) and vim.api.nvim_win_get_buf(ctx.win) == buf) then
      return
    end
    if vim.api.nvim_buf_line_count(buf) < row and tries < 50 then
      return vim.defer_fn(scroll, 10)
    end
    vim.api.nvim_win_call(ctx.win, function()
      pcall(vim.api.nvim_win_set_cursor, ctx.win, { row, 0 })
      vim.cmd("normal! zt")
    end)
  end
  vim.defer_fn(scroll, 10)
end

return {
  "folke/snacks.nvim",
  opts = {
    picker = {
      sources = {
        git_diff = {
          formatters = { file = { filename_first = true } },
          layout = {
            fullscreen = true,
            layout = {
              box = "vertical",
              {
                box = "vertical",
                border = true,
                title = "{title} {live} {flags}",
                height = 0.25,
                { win = "input", height = 1, border = "bottom" },
                { win = "list", border = "none" },
              },
              { win = "preview", title = "{preview}", border = true },
            },
          },
          preview = full_file_diff,
        },
      },
    },
  },
}
