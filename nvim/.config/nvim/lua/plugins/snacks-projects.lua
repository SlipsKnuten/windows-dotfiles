-- Switching project replaces the workspace: the current project's session is saved and its
-- buffers closed, then the chosen project's session is restored (or its file picker opened).
local function switch_project(picker, item)
  picker:close()
  if not item then
    return
  end

  local modified = vim.tbl_filter(function(buf)
    return vim.bo[buf].buflisted and vim.bo[buf].modified
  end, vim.api.nvim_list_bufs())
  if #modified > 0 then
    Snacks.notify.warn("Save or discard your changes before switching project")
    return
  end

  local tree_open = vim.iter(vim.api.nvim_tabpage_list_wins(0)):any(function(win)
    return vim.bo[vim.api.nvim_win_get_buf(win)].filetype == "neo-tree"
  end)

  local persistence = require("persistence")
  local has_files = vim.iter(vim.api.nvim_list_bufs()):any(function(buf)
    return vim.bo[buf].buflisted and vim.bo[buf].buftype == "" and vim.api.nvim_buf_get_name(buf) ~= ""
  end)
  if has_files then
    vim.api.nvim_exec_autocmds("User", { pattern = "PersistenceSavePre" })
    persistence.save()
  end

  if tree_open then
    vim.cmd("Neotree close")
  end
  -- wipe rather than delete: deleted buffers linger unlisted and would leak into the next
  -- project's saved session
  Snacks.bufdelete.all({ wipe = true })
  vim.fn.chdir(item.file)

  local session = persistence.current()
  if vim.fn.filereadable(session) == 0 then
    session = persistence.current({ branch = false })
  end
  local has_session = vim.fn.filereadable(session) == 1
  if has_session then
    persistence.load()
  end
  if tree_open then
    -- name the directory: the tree otherwise keeps the root it was last opened with
    vim.cmd("Neotree show dir=" .. vim.fn.fnameescape(item.file))
  end
  if not has_session then
    -- wait for the file tree to finish opening, or it takes focus and closes the picker
    vim.defer_fn(Snacks.picker.files, 150)
  end
end

return {
  "folke/snacks.nvim",
  keys = {
    { "<leader>pp", function() Snacks.picker.projects() end, desc = "Switch Project" },
    { "<C-p>", function() Snacks.picker.projects() end, desc = "Switch Project" },
  },
  opts = {
    picker = {
      sources = {
        projects = { confirm = switch_project },
      },
    },
  },
}
