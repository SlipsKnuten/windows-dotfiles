-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

vim.keymap.set("i", "jj", "<Esc>", { desc = "Exit insert mode" })
vim.keymap.set("v", "jj", "<Esc>", { desc = "Exit visual mode" })

local inside_pairs = {
  { opener = "(", closer = ")" },
  { opener = "{", closer = "}" },
  { opener = "[", closer = "]" },
  { opener = '"', closer = '"' },
  { opener = "'", closer = "'" },
}

local function is_escaped(line, col)
  local backslashes = 0
  for i = col - 1, 1, -1 do
    if line:sub(i, i) ~= "\\" then
      break
    end
    backslashes = backslashes + 1
  end
  return backslashes % 2 == 1
end

local function quote_is_closing(line, quote, col)
  local quotes_before = 0
  for i = 1, col - 1 do
    if line:sub(i, i) == quote and not is_escaped(line, i) then
      quotes_before = quotes_before + 1
    end
  end
  return quotes_before % 2 == 1
end

local function find_pair_end(line, pair, start_col)
  local opener = pair.opener
  local closer = pair.closer

  if opener == closer then
    for col = start_col + 1, #line do
      if line:sub(col, col) == closer and not is_escaped(line, col) then
        return col
      end
    end
    return nil
  end

  local depth = 0
  for col = start_col, #line do
    local char = line:sub(col, col)
    if char == opener then
      depth = depth + 1
    elseif char == closer then
      depth = depth - 1
      if depth == 0 then
        return col
      end
    end
  end
end

local function find_pair_start(line, pair, end_col)
  local opener = pair.opener
  local closer = pair.closer

  if opener == closer then
    for col = end_col - 1, 1, -1 do
      if line:sub(col, col) == opener and not is_escaped(line, col) then
        return col
      end
    end
    return nil
  end

  local depth = 0
  for col = end_col, 1, -1 do
    local char = line:sub(col, col)
    if char == closer then
      depth = depth + 1
    elseif char == opener then
      depth = depth - 1
      if depth == 0 then
        return col
      end
    end
  end
end

local function find_current_closer_target(line, cursor_col)
  local char = line:sub(cursor_col, cursor_col)

  for _, pair in ipairs(inside_pairs) do
    if char == pair.closer then
      local escaped_or_opening_quote = pair.opener == pair.closer
        and (is_escaped(line, cursor_col) or not quote_is_closing(line, char, cursor_col))
      if escaped_or_opening_quote then
        return nil
      end

      local opener_col = find_pair_start(line, pair, cursor_col)
      if opener_col then
        return cursor_col - 1
      end
    end
  end
end

local function find_next_opener_target(line, cursor_col)
  local target_col
  local best_distance

  for col = math.max(cursor_col, 1), #line do
    local char = line:sub(col, col)

    for _, pair in ipairs(inside_pairs) do
      if char == pair.opener then
        local is_closing_quote = pair.opener == pair.closer
          and (is_escaped(line, col) or quote_is_closing(line, char, col))
        local closer_col = find_pair_end(line, pair, col)
        if not is_closing_quote and closer_col then
          local distance = col - cursor_col
          if not best_distance or distance < best_distance then
            best_distance = distance
            target_col = closer_col - 1
          end
        end
        break
      end
    end
  end

  return target_col
end

vim.keymap.set("n", "q", function()
  if vim.fn.reg_recording() ~= "" then
    vim.api.nvim_feedkeys("q", "n", false)
    return
  end

  local cursor = vim.api.nvim_win_get_cursor(0)
  local row = cursor[1]
  local cursor_col = cursor[2] + 1
  local line = vim.api.nvim_get_current_line()
  local target_col = find_current_closer_target(line, cursor_col)
    or find_next_opener_target(line, cursor_col)

  if target_col then
    vim.api.nvim_win_set_cursor(0, { row, target_col })
    vim.cmd.startinsert()
  else
    vim.api.nvim_feedkeys("q", "n", false)
  end
end, { desc = "Jump inside next pair" })

-- Alt+j/k to move 5 lines at a time
-- (was <D-...> which is macOS Cmd; Super/Windows-key is intercepted by the
-- desktop on both Hyprland and Windows, so Alt is the portable choice.)
vim.keymap.set({ "n", "v" }, "<M-j>", "5j", { desc = "Move down 5 lines" })
vim.keymap.set({ "n", "v" }, "<M-k>", "5k", { desc = "Move up 5 lines" })

-- Alt+h/l to go to beginning/end of line
vim.keymap.set({ "n", "v" }, "<M-h>", "^", { desc = "Go to beginning of line" })
vim.keymap.set({ "n", "v" }, "<M-l>", "$", { desc = "Go to end of line" })
vim.keymap.set("i", "<M-h>", "<Home>", { desc = "Go to beginning of line" })
vim.keymap.set("i", "<M-l>", "<End>", { desc = "Go to end of line" })

-- Swap i and a: i inserts after cursor, a inserts before
vim.keymap.set("n", "i", "a", { noremap = true, desc = "Insert after cursor" })
vim.keymap.set("n", "a", "i", { noremap = true, desc = "Insert before cursor" })

-- Prevent cursor from jumping back when leaving insert mode
vim.api.nvim_create_autocmd("InsertLeave", {
  callback = function()
    local cur = vim.api.nvim_win_get_cursor(0)
    local line = vim.api.nvim_get_current_line()
    if cur[2] > 0 and cur[2] < #line then
      vim.api.nvim_win_set_cursor(0, { cur[1], cur[2] + 1 })
    end
  end,
  desc = "Prevent cursor from moving back on insert leave",
})
