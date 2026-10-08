-- jira-cli hard-wraps `issue view --plain` at 120 columns (2 of them margin), which splits
-- paragraphs and URLs over several lines, and it indents nested bullets far enough that
-- jira.nvim mistakes them for code. Undo both before jira.nvim converts the text to markdown.
local WRAP_WIDTH = 116
local NBSP = "\194\160"

local function unwrap_cli_output(text)
  local out, last_width = {}, 0
  for _, line in ipairs(vim.split(text:gsub("\27%[[0-9;]*m", ""), "\n", { plain = true })) do
    line = line:gsub("%s+$", "")
    local prev = out[#out]
    local is_header = line:match("^%s*%-%-%-+%s+.-%s+%-%-%-+$") ~= nil
    local indent, body = line:match("^(%s*)(.*)$")
    local first = body:match("^%S+") or ""
    local width = vim.fn.strdisplaywidth(line)

    -- a line continues the previous one if its first word would not have fit there
    local in_url = prev and prev:match("%S+$") and prev:match("%S+$"):find("://", 1, true) and prev:match("[%./,%-]$")
    local glue = in_url and "" or " "
    local continues = prev
      and prev ~= ""
      and body ~= ""
      and not is_header
      and not prev:match("^%s*%-%-%-+%s")
      and not body:match("^•")
      and not body:match("^%u[%u%d]+%-%d+%s") -- linked issue rows
      and indent == prev:match("^%s*")
      and last_width + #glue + vim.fn.strdisplaywidth(first) > WRAP_WIDTH

    if continues then
      out[#out] = prev .. glue .. body
    else
      out[#out + 1] = line
    end
    last_width = width
  end

  for i, line in ipairs(out) do
    local indent, item = line:match("^  (%s*)• (.*)$")
    if indent then
      -- non-breaking spaces keep the nesting without tripping the indented-code detection
      out[i] = "  " .. NBSP:rep(#indent / 2) .. "- " .. item
    end
  end
  return table.concat(out, "\n")
end

-- long bare URLs become markdown links labelled with their host, so they conceal to a few words
local function shorten_url(url)
  local host = url:match("^%a+://([^/]+)")
  if #url < 60 or not host or url:find("[()]") then
    return url
  end
  return ("[%s](%s)"):format(host, url)
end

local function tidy_markdown(lines)
  local out = {}
  for _, line in ipairs(lines) do
    local depth = 0
    while line:sub(depth * #NBSP + 1, (depth + 1) * #NBSP) == NBSP do
      depth = depth + 1
    end
    line = (" "):rep(depth) .. line:sub(depth * #NBSP + 1)
    line = line:gsub("%a+://%S+", shorten_url)

    local prev = out[#out]
    local is_item = line:match("^%s*%- ") ~= nil
    if prev and prev:match("^%s*%- ") and line ~= "" and not is_item then
      -- without a blank line the text would be read as part of the last list item
      out[#out + 1] = ""
    end
    if not (line == "" and out[#out] == "") then
      out[#out + 1] = line
    end
  end
  return out
end

return {
  "l-lin/jira.nvim",
  dependencies = { "folke/snacks.nvim" },
  cmd = { "JiraIssues", "JiraEpic", "JiraStartWorkingOn" },
  keys = {
    { "<leader>ji", "<cmd>JiraIssues<cr>", desc = "Jira Issues (current sprint)" },
    { "<leader>je", "<cmd>JiraEpic<cr>", desc = "Jira Epics" },
  },
  opts = {
    cli = {
      -- DNAMINDL has no "archive" status, and Jira rejects filters on unknown statuses
      issues = { filters = { "-s~done" } },
      epic_issues = { filters = { "-s~done" } },
      epics = {
        -- DNAMINDL has no Epic issue type; its epics live in the DNA project
        args = { "issue", "list", "--type", "Epic", "-p", "DNA" },
      },
    },
    layout = {
      issues = { preset = "default", fullscreen = true },
      epic_issues = { preset = "default", fullscreen = true },
      -- the default caps this picker at 120 columns, and opts are merged into it
      epics = { preset = "default", fullscreen = true, hidden = { "preview" }, layout = { max_width = 9999 } },
    },
  },
  config = function(_, opts)
    require("jira").setup(opts)

    local markdown = require("jira.markdown")
    local format_issue = markdown.format_issue
    markdown.format_issue = function(text, issue_key, epic)
      return tidy_markdown(format_issue(unwrap_cli_output(text), issue_key, epic))
    end

    -- issue buffers are read-only prose: no spell check, gutter, or mid-word wrapping
    vim.api.nvim_create_autocmd({ "FileType", "BufWinEnter" }, {
      group = vim.api.nvim_create_augroup("jira_issue_view", { clear = true }),
      callback = function(ev)
        if not vim.api.nvim_buf_get_name(ev.buf):match("^jira://") then
          return
        end
        vim.schedule(function()
          for _, win in ipairs(vim.fn.win_findbuf(ev.buf)) do
            local wo = vim.wo[win][0]
            wo.spell = false
            wo.number = false
            wo.relativenumber = false
            wo.signcolumn = "no"
            wo.wrap = true
            wo.linebreak = true
            wo.breakindent = true
            wo.conceallevel = 2
          end
        end)
      end,
    })
  end,
}
