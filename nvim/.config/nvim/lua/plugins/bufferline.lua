-- Compact bufferline that shrinks its tabs so every buffer stays on screen.
-- Each render tries the roomiest layout first and only tightens as far as
-- needed for the current width (terminal resize, zoom, neo-tree open, ...).

-- Shrink steps, cumulative and in order of how much they cost in readability
local steps = {
  function(o) o.buffer_close_icon = "" end, -- drops the left padding cell
  function(o) o.numbers = function(n) return n.raise(n.ordinal) end end, -- "1." -> "¹"
  function(o) o.offsets = {} end, -- let tabs run above neo-tree
  function() require("bufferline.constants").padding = "" end, -- no gaps inside a tab
  function(o) o.modified_icon = "" end, -- drops the modified-dot cell
}
local managed = { "buffer_close_icon", "numbers", "offsets", "modified_icon", "truncate_names", "max_name_length" }

local function dynamic(render)
  return function()
    local options = require("bufferline.config").options
    local constants = require("bufferline.constants")
    local state = require("bufferline.state")
    local saved, padding = {}, constants.padding
    for _, key in ipairs(managed) do
      saved[key] = options[key]
    end

    local str, segments
    local function fits(level, cap)
      constants.padding = padding
      for _, key in ipairs(managed) do
        options[key] = saved[key]
      end
      for i = 1, level do
        steps[i](options)
      end
      if cap then
        options.truncate_names, options.max_name_length = true, cap
      end
      str, segments = render()
      return #(state.visible_components or {}) >= #(state.components or {})
    end

    local ok, err = pcall(function()
      for level = 0, #steps do
        if fits(level) then return end
      end
      -- Last resort, nothing left to trim but the names: find the longest
      -- name length at which all tabs still fit
      local lo, hi, best = 1, 0, 1
      for _, item in ipairs(state.components or {}) do
        hi = math.max(hi, vim.api.nvim_strwidth(item.name or "") - 1)
      end
      while lo <= hi do
        local mid = math.floor((lo + hi) / 2)
        if fits(#steps, mid) then
          best, lo = mid, mid + 1
        else
          hi = mid - 1
        end
      end
      fits(#steps, best)
    end)

    constants.padding = padding
    for _, key in ipairs(managed) do
      options[key] = saved[key]
    end
    if not ok then error(err, 0) end
    return str, segments
  end
end

return {
  "akinsho/bufferline.nvim",
  opts = function(_, opts)
    opts.options = vim.tbl_deep_extend("force", opts.options or {}, {
      tab_size = 0,
      truncate_names = false, -- always show the full filename
      show_buffer_close_icons = false,
      show_close_icon = false,
      show_buffer_icons = false,
      diagnostics = false,
      separator_style = { "", "" },
      indicator = { style = "none" },
      numbers = "ordinal", -- matches the Alt+1-9 BufferLineGoToBuffer keymaps
    })

    require("bufferline") -- defines the global the tabline option calls
    if not vim.g.bufferline_dynamic then
      vim.g.bufferline_dynamic = true
      _G.nvim_bufferline = dynamic(_G.nvim_bufferline)
    end
  end,
}
