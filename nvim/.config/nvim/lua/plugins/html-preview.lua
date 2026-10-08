-- HTML preview helpers (WSL2 -> Windows browser)
--
--  <leader>bp  : open the current file in the default Windows browser (file://)
--  <leader>bs  : serve the file's directory with live-server and open it
--                (auto-reloads when files on disk change, e.g. after
--                 `python3 make_viewer.py`); press again to stop.

local function open_in_browser()
  local file = vim.api.nvim_buf_get_name(0)
  if file == "" then
    vim.notify("No file in this buffer", vim.log.levels.WARN)
    return
  end
  -- vim.ui.open picks explorer.exe / wslview / xdg-open automatically.
  vim.ui.open(file)
end

local live_server_job = nil

local function toggle_live_server()
  if live_server_job then
    vim.fn.jobstop(live_server_job)
    live_server_job = nil
    vim.notify("live-server stopped")
    return
  end

  local file = vim.api.nvim_buf_get_name(0)
  local dir = file ~= "" and vim.fs.dirname(file) or vim.fn.getcwd()
  local entry = file ~= "" and vim.fs.basename(file) or "index.html"

  live_server_job = vim.fn.jobstart(
    { "npx", "--yes", "live-server", "--port=5500", "--open=" .. entry },
    {
      cwd = dir,
      on_exit = function()
        live_server_job = nil
      end,
    }
  )

  if live_server_job > 0 then
    vim.notify("live-server on http://localhost:5500 (" .. entry .. ")")
  else
    live_server_job = nil
    vim.notify("Failed to start live-server (is Node installed?)", vim.log.levels.ERROR)
  end
end

vim.api.nvim_create_autocmd("VimLeavePre", {
  callback = function()
    if live_server_job then
      vim.fn.jobstop(live_server_job)
    end
  end,
})

return {
  {
    "LazyVim/LazyVim",
    init = function()
      vim.keymap.set("n", "<leader>bp", open_in_browser, { desc = "Preview file in browser" })
      vim.keymap.set("n", "<leader>bs", toggle_live_server, { desc = "Serve dir (live-server) / stop" })
    end,
  },
}
