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

-- the token goes into an HTTP header, so anything besides the token itself (stderr notices,
-- terminal escape sequences, line breaks) makes every request fail
local function glab_token(host)
  local ok, result = pcall(function()
    return vim.system({ "glab", "config", "get", "token", "--host", host }, { text = true }):wait()
  end)
  if not ok then
    return nil, "could not run glab: " .. tostring(result)
  end
  local out = (result.stdout or "")
    :gsub("\27%].-\27\\", "") -- OSC sequences, e.g. Windows Terminal's cwd reporting
    :gsub("\27%].-\7", "")
    :gsub("\27%[[%d;?]*%a", "") -- colours and other CSI sequences
  local token
  for line in out:gmatch("[^\r\n]+") do
    line = vim.trim(line)
    if line ~= "" then
      token = line
    end
  end
  if result.code ~= 0 or not token then
    return nil, ("no glab token for %s; run `glab auth login --hostname %s`"):format(host, host)
  end
  if not token:match("^[%w%-%._]+$") then
    return nil, ("glab returned an unexpected token for %s (%d characters, %d not allowed in a token)"):format(
      host,
      #token,
      select(2, token:gsub("[^%w%-%._]", ""))
    )
  end
  return token
end

local function auth_provider()
  local host = remote_host()
  local token, err = glab_token(host)
  if not token then
    vim.notify("gitlab.nvim: " .. err, vim.log.levels.ERROR)
    return nil, nil, err
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
  init = function()
    -- the plugin checks for Go every time it starts, and Neovim may not have been launched from a
    -- shell that activated mise
    local shims = vim.fn.expand("~/.local/share/mise/shims")
    if vim.fn.executable("go") == 0 and vim.fn.isdirectory(shims) == 1 then
      vim.env.PATH = shims .. ":" .. vim.env.PATH
    end
  end,
  opts = {
    auth_provider = auth_provider,
  },
}
