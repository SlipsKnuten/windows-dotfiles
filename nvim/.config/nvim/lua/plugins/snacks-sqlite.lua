-- Only the versioned libsqlite3.so.0 is installed (no -dev symlink), so ffi.load("sqlite3")
-- fails; point snacks at it directly. Used by jira.nvim's cache.
local lib = "/usr/lib/x86_64-linux-gnu/libsqlite3.so.0"

return {
  "folke/snacks.nvim",
  opts = {
    picker = {
      db = { sqlite3_path = vim.uv.fs_stat(lib) and lib or nil },
    },
  },
}
