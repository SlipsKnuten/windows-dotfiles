-- Merge request reviews with gitlab.nvim, on its default settings and keymaps (all start with gl).
-- It builds a small Go server on first use, so Go has to be on PATH (it comes from mise).
--
-- The only change from the defaults: the token comes from glab, for the GitLab host of the
-- repo's origin remote, so there is no separate token to create or keep in sync.

local DEFAULT_HOST = "git-tos.intern.folksam.se"

local function remote_host()
  local url = vim.trim(vim.fn.system({ "git", "remote", "get-url", "origin" }))
  if vim.v.shell_error ~= 0 then
    return DEFAULT_HOST
  end
  -- https://user@host:port/group/repo.git, ssh://git@host:22/..., or git@host:group/repo.git
  local host = url:match("^%a+://([^/]+)") or url:match("^[^@/]+@([^:/]+):")
  if not host then
    return DEFAULT_HOST
  end
  host = host:gsub("^.*@", ""):gsub(":%d+$", "")
  return host
end

local function auth_provider()
  local host = remote_host()
  local token = vim.trim(vim.fn.system({ "glab", "config", "get", "token", "--host", host }))
  if vim.v.shell_error ~= 0 or token == "" then
    return nil, nil, ("no glab token for %s; run `glab auth login --hostname %s`"):format(host, host)
  end
  return token, "https://" .. host, nil
end

return {
  "harrisoncramer/gitlab.nvim",
  dependencies = {
    "MunifTanjim/nui.nvim",
    "dlyongemallo/diffview-plus.nvim", -- maintained diffview fork that gitlab.nvim recommends
  },
  -- load at startup so the gl… keymaps are there right away
  event = "VeryLazy",
  opts = {
    auth_provider = auth_provider,
  },
}
