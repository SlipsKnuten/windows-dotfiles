-- Reopen the buffers from the last session in this directory when Neovim starts without
-- file arguments (or with just the current directory). Sessions are saved per directory
-- (and git branch) by persistence.nvim.
---Show `target` (the buffer the session made current) in the main window and focus it.
---@param target number
local function focus_file(target)
  if not vim.api.nvim_buf_is_valid(target) then
    return
  end
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local buf = vim.api.nvim_win_get_buf(win)
    if vim.bo[buf].buftype == "" and vim.api.nvim_win_get_config(win).relative == "" then
      vim.api.nvim_set_current_win(win)
      vim.api.nvim_win_set_buf(win, target)
      -- drop the empty buffer the file tree leaves behind when it replaces the directory
      if buf ~= target and vim.api.nvim_buf_get_name(buf) == "" and not vim.bo[buf].modified then
        pcall(vim.api.nvim_buf_delete, buf, { force = true })
      end
      return
    end
  end
end

return {
  "folke/persistence.nvim",
  init = function()
    vim.api.nvim_create_autocmd("StdinReadPre", {
      callback = function()
        vim.g.started_with_stdin = true
      end,
    })
    vim.api.nvim_create_autocmd("VimEnter", {
      nested = true,
      callback = function()
        -- `nvim` and `nvim .` both mean "open this project"
        local argc = vim.fn.argc(-1)
        local arg = vim.fn.argv(0, -1)
        local opens_cwd = argc == 0
          or (argc == 1 and vim.fn.isdirectory(arg) == 1 and vim.uv.fs_realpath(arg) == vim.uv.fs_realpath(vim.fn.getcwd()))
        if opens_cwd and not vim.g.started_with_stdin then
          -- loading during VimEnter itself leaves the restored buffer without a filetype
          vim.schedule(function()
            require("persistence").load()
            local target = vim.api.nvim_get_current_buf()
            -- with `nvim .` the file tree opens afterwards, takes the cursor and swaps the
            -- window to another buffer
            vim.api.nvim_create_autocmd("FileType", {
              pattern = "neo-tree",
              once = true,
              callback = function()
                vim.defer_fn(function()
                  focus_file(target)
                end, 50)
              end,
            })
          end)
        end
      end,
    })
    -- A session saved from `nvim .` reopens the directory itself as a buffer, and one saved
    -- with the cursor outside a file leaves an empty buffer in front; show neither as a tab.
    vim.api.nvim_create_autocmd("User", {
      pattern = "PersistenceLoadPost",
      nested = true, -- so the file shown below still gets its filetype
      callback = function()
        local files = {}
        for _, buf in ipairs(vim.api.nvim_list_bufs()) do
          local name = vim.api.nvim_buf_get_name(buf)
          if vim.fn.isdirectory(name) == 1 then
            vim.bo[buf].buflisted = false
          elseif vim.bo[buf].buflisted and vim.bo[buf].buftype == "" and name ~= "" then
            files[#files + 1] = buf
          end
        end
        local cur = vim.api.nvim_get_current_buf()
        if #files > 0 and not vim.tbl_contains(files, cur) then
          local shown = files[#files]
          vim.api.nvim_win_set_buf(0, shown)
          -- at startup the buffer is read before filetype detection is ready
          vim.schedule(function()
            if vim.api.nvim_buf_is_valid(shown) and vim.bo[shown].filetype == "" then
              vim.api.nvim_buf_call(shown, function()
                vim.cmd("filetype detect")
              end)
            end
          end)
          local is_empty = vim.api.nvim_buf_is_valid(cur) and vim.bo[cur].buftype == "" and vim.api.nvim_buf_get_name(cur) == ""
          if is_empty and not vim.bo[cur].modified then
            pcall(vim.api.nvim_buf_delete, cur, { force = true })
          end
        end
      end,
    })
    -- Jira issue buffers cannot be reloaded from a session file
    vim.api.nvim_create_autocmd("User", {
      pattern = "PersistenceSavePre",
      callback = function()
        -- keep `nvim .`'s directory argument out of the session
        vim.cmd("silent! %argdelete")
        for _, buf in ipairs(vim.api.nvim_list_bufs()) do
          if vim.api.nvim_buf_get_name(buf):match("^jira://") then
            vim.api.nvim_buf_delete(buf, { force = true })
          end
        end
      end,
    })
  end,
}
