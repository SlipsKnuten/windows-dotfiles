-- Reopen the buffers from the last session in this directory when Neovim starts without
-- file arguments. Sessions are saved per directory (and git branch) by persistence.nvim.
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
        if vim.fn.argc(-1) == 0 and not vim.g.started_with_stdin then
          require("persistence").load()
        end
      end,
    })
    -- Jira issue buffers cannot be reloaded from a session file
    vim.api.nvim_create_autocmd("User", {
      pattern = "PersistenceSavePre",
      callback = function()
        for _, buf in ipairs(vim.api.nvim_list_bufs()) do
          if vim.api.nvim_buf_get_name(buf):match("^jira://") then
            vim.api.nvim_buf_delete(buf, { force = true })
          end
        end
      end,
    })
  end,
}
