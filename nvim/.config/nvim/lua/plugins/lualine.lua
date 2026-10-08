-- Statusline that always shows the full file path: right-side sections are
-- hidden whenever they would squeeze the path (e.g. when the terminal is zoomed in)

-- true when the bar has `extra` columns to spare beyond mode + branch + full path
local function room_for(extra)
  return function()
    local path = vim.fn.expand("%:~:.")
    local branch = vim.b.gitsigns_head or ""
    return vim.o.columns > 20 + #branch + #path + extra
  end
end

local function add_cond(c, cond)
  if type(c) ~= "table" then
    c = { c }
  end
  local old = c.cond
  c.cond = function()
    return cond() and (old == nil or old())
  end
  return c
end

return {
  "nvim-lualine/lualine.nvim",
  opts = function(_, opts)
    local c = opts.sections.lualine_c

    -- lualine_c[4] is LazyVim's pretty_path(); length = 0 disables truncation
    c[4] = { LazyVim.lualine.pretty_path({ length = 0 }) }

    -- drop the trouble.nvim symbol breadcrumb so it doesn't crowd the path
    for i = #c, 5, -1 do
      table.remove(c, i)
    end

    -- root dir / diagnostics / filetype icon go first when space is tight
    for i = 1, 3 do
      c[i] = add_cond(c[i], room_for(60))
    end

    -- lsp status, diff, etc. next; then progress / location / clock
    for _, name in ipairs({ "lualine_x", "lualine_y", "lualine_z" }) do
      local extra = name == "lualine_x" and 50 or 25
      for i, comp in ipairs(opts.sections[name] or {}) do
        opts.sections[name][i] = add_cond(comp, room_for(extra))
      end
    end
  end,
}
