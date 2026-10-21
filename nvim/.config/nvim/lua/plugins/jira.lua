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

-- jira-cli returns at most 100 issues and ignores the page offset on Jira Cloud, so a picker
-- can never hold a whole project. Instead the issue and epic pickers search on the server as
-- you type (snacks "live" mode; <c-g> switches to fuzzy filtering of the loaded results).
local PROJECT = "DNAMINDL"
local EPIC_PROJECT = "DNA"

local function parse_csv_line(line)
  local values, current, in_quotes = {}, {}, false
  for char in line:gmatch(".") do
    if char == '"' then
      in_quotes = not in_quotes
    elseif char == "," and not in_quotes then
      values[#values + 1] = table.concat(current)
      current = {}
    else
      current[#current + 1] = char
    end
  end
  values[#values + 1] = table.concat(current)
  return values
end

-- an issue key or number looks the issue up; other text is a full-text search, with the last
-- word matched as a prefix so results appear while a word is still being typed
local function search_jql(text, project)
  text = vim.trim(text or "")
  local key = text:upper():match("^%u[%u%d]*%-%d+$")
  if key then
    return ('key = "%s"'):format(key)
  end
  -- characters with a meaning in Jira's text search make the whole query fail
  local words = vim.trim((text:gsub('[%+%-&|!(){}%[%]^~*?\\:"/]', " ")))
  if words == "" then
    return nil
  end
  local jql = ('text ~ "%s*"'):format(words)
  if words:match("^%d+$") then
    jql = ('key = "%s-%s" OR %s'):format(project, words, jql)
  end
  return jql
end

local function list_args(args, filters, clauses, order_by, columns)
  args = vim.list_extend(vim.deepcopy(args), filters)
  if #clauses > 0 then
    vim.list_extend(args, { "-q", "(" .. table.concat(clauses, ") AND (") .. ")" })
  end
  return vim.list_extend(args, { "--order-by", order_by, "--csv", "--columns", table.concat(columns, ",") })
end

local BOARD_SCRIPT = vim.fn.stdpath("config") .. "/scripts/jira_board.py"
local BOARDS = {
  { id = 1258, name = "Sync Board (Dev)" },
  { id = 719, name = "Refine & Rank" },
}

-- the "Silo GenAI" quick filter from the boards; <a-g> toggles it in every picker, and the
-- choice carries over to the next picker until Neovim restarts
local GENAI_JQL = "component = GenAI"
local state = { genai = true }

local function genai_clause()
  return state.genai and GENAI_JQL or nil
end

-- JQL clauses to AND together, skipping the nil ones
local function clauses(...)
  local out = {}
  for i = 1, select("#", ...) do
    out[#out + 1] = select(i, ...)
  end
  return out
end

-- `query(opts, search)` returns { args, cmd?, columns | decode = "json", transform, cache?, notify? }.
-- Only queries without search text are cached, so reopening a picker is instant but searches
-- are always fresh.
local function server_finder(query)
  return function(opts, ctx)
    local q = query(opts, ctx.filter.search)
    local cache = require("jira.cache")
    if q.cache then
      local cached = cache.get(q.cache.key, q.cache.params)
      if cached and cached.items then
        return ctx.filter:filter(cached.items)
      end
    end

    local header = q.columns and table.concat(q.columns, ","):upper()
    local proc = require("snacks.picker.source.proc").proc(
      ctx:opts({
        cmd = q.cmd or require("jira.config").options.cli.cmd,
        args = q.args,
        notify = q.notify or false, -- jira-cli exits with an error when nothing matches
        transform = function(item)
          if q.decode == "json" then
            local ok, row = pcall(vim.json.decode, item.text)
            return ok and q.transform(row) or false
          end
          local values = parse_csv_line(item.text)
          if item.text == header or #values < #q.columns then
            return false
          end
          local row = {}
          for i, column in ipairs(q.columns) do
            -- jira-cli escapes "[text]" as "[text[]"
            row[column] = values[i]:gsub("%[([^%]]+)%[%]", "[%1]")
          end
          return q.transform(row)
        end,
      }),
      ctx
    )
    if not q.cache then
      return proc
    end

    ---@async
    return function(cb)
      local items = {}
      proc(function(item)
        items[#items + 1] = item
        cb(item)
      end)
      if #items > 0 then
        vim.schedule(function()
          cache.set(q.cache.key, q.cache.params, items)
        end)
      end
    end
  end
end

-- same items as jira.nvim's own finders build, so its formatters, previews and actions work
local function issue_item(row)
  return {
    text = table.concat({ row.key, row.assignee, row.status, row.summary, row.labels }, " "),
    key = row.key,
    type = row.type,
    assignee = row.assignee,
    status = row.status,
    summary = row.summary,
    labels = row.labels,
    _raw = row,
  }
end

local function epic_item(row)
  local icons = require("jira.config").options.ui.type_icons
  return {
    text = ("%s %s %s"):format(icons.Epic or icons.default, row.key, row.summary),
    key = row.key,
    type = "Epic",
    status = row.status,
    summary = row.summary,
    _raw = row,
  }
end

-- whole project by default (done issues included, newest activity first);
-- `opts.sprint` limits it to the open sprint and hides done issues, like before
local issues_finder = server_finder(function(opts, search)
  local cli = require("jira.config").options.cli.issues
  local text = search_jql(search, PROJECT)
  return {
    args = list_args(
      { "issue", "list" },
      opts.sprint and cli.filters or {},
      clauses(opts.sprint and "sprint in openSprints()" or nil, genai_clause(), text),
      opts.sprint and cli.order_by or "updated",
      cli.columns
    ),
    columns = cli.columns,
    transform = issue_item,
    cache = not text and {
      key = "issues",
      params = { scope = opts.sprint and "sprint" or "project", genai = state.genai },
    } or nil,
  }
end)

local epics_finder = server_finder(function(_, search)
  local cli = require("jira.config").options.cli.epics
  local text = search_jql(search, EPIC_PROJECT)
  return {
    args = list_args(cli.args, cli.filters, clauses(genai_clause(), text), cli.order_by, cli.columns),
    columns = cli.columns,
    transform = epic_item,
    cache = not text and { key = "epics", params = { scope = "search", genai = state.genai } } or nil,
  }
end)

local function epic_issues_finder(epic_key)
  return server_finder(function()
    local cli = require("jira.config").options.cli.epic_issues
    return {
      args = list_args({ "issue", "list", "--parent", epic_key }, cli.filters, clauses(genai_clause()), cli.order_by, cli.columns),
      columns = cli.columns,
      transform = issue_item,
      -- jira.nvim clears "epic_issues*" and "issues*" caches after changing an issue
      cache = { key = "epic_issues", params = { epic_key = epic_key, genai = state.genai } },
    }
  end)
end

-- all of a board's issues, in board-column order and then by rank (see scripts/jira_board.py)
local function board_finder(board)
  return server_finder(function()
    return {
      cmd = "python3",
      args = { "-I", BOARD_SCRIPT, tostring(board.id), genai_clause() or "" },
      decode = "json",
      notify = true,
      transform = function(row)
        local item = issue_item(row)
        item.column = row.column
        item.text = row.column .. " " .. item.text
        return item
      end,
      cache = { key = "issues", params = { board = board.id, genai = state.genai } },
    }
  end)
end

local COLUMN_WIDTH = 17

local function format_board_issue(item, picker)
  local hl = require("jira.config").options.ui.status_highlights[item.status] or "Comment"
  local column = item.column or ""
  local ret = { { column .. (" "):rep(math.max(1, COLUMN_WIDTH - vim.fn.strdisplaywidth(column))), hl } }
  return vim.list_extend(ret, require("jira.picker.formatters").format_jira_issues(item, picker))
end

local function picker_title(picker)
  local parts = { picker.opts.jira_title }
  if picker.opts.sprint then
    parts[#parts + 1] = "current sprint"
  end
  if state.genai then
    parts[#parts + 1] = "Silo GenAI"
  end
  return table.concat(parts, " · ")
end

local function show_title(picker)
  picker.title = picker_title(picker)
  picker:update_titles()
end

local TOGGLES = {
  sprint = {
    key = "<c-s>",
    action = function(picker)
      picker.opts.sprint = not picker.opts.sprint
    end,
  },
  genai = {
    key = "<a-g>",
    action = function()
      state.genai = not state.genai
    end,
  },
}

-- adds the named toggles' keys and actions to a picker source, and keeps its title in sync
local function add_toggles(src, names)
  src.actions = src.actions or {}
  src.on_show = show_title
  src.win = src.win or {}
  for _, win in ipairs({ "input", "list" }) do
    src.win[win] = src.win[win] or {}
    -- copy: jira.nvim shares one keys table between all of its pickers
    local keys = vim.tbl_extend("force", {}, src.win[win].keys or {})
    for _, name in ipairs(names) do
      local action = "jira_toggle_" .. name
      src.actions[action] = function(picker)
        TOGGLES[name].action(picker)
        picker.title = picker_title(picker)
        picker:refresh()
      end
      keys[TOGGLES[name].key] = win == "input" and { action, mode = { "i", "n" } } or action
    end
    src.win[win].keys = keys
  end
  return src
end

local function board_source(board)
  local config = require("jira.config").options
  return add_toggles({
    jira_title = "JIRA Board · " .. board.name,
    layout = config.layout.issues,
    finder = board_finder(board),
    format = format_board_issue,
    preview = "preview_jira_issue",
    confirm = "action_jira_list_actions",
    win = {
      input = { title = "{title}", keys = config.keymaps.input },
      list = { keys = config.keymaps.list },
      preview = { keys = config.keymaps.preview },
    },
  }, { "genai" })
end

local function open_issues(sprint)
  require("jira").open_jira_issues({ sprint = sprint })
end

local function open_board()
  if not package.loaded["jira.picker"] then
    require("jira.picker").register()
  end
  vim.ui.select(BOARDS, {
    prompt = "Jira board",
    format_item = function(board)
      return board.name
    end,
  }, function(board)
    if board then
      require("snacks").picker(board_source(board))
    end
  end)
end

return {
  "l-lin/jira.nvim",
  dependencies = { "folke/snacks.nvim" },
  cmd = { "JiraIssues", "JiraEpic", "JiraStartWorkingOn" },
  keys = {
    {
      "<leader>ji",
      function()
        open_issues(false)
      end,
      desc = "Jira Issues (search " .. PROJECT .. ")",
    },
    {
      "<leader>js",
      function()
        open_issues(true)
      end,
      desc = "Jira Issues (current sprint)",
    },
    { "<leader>je", "<cmd>JiraEpic<cr>", desc = "Jira Epics" },
    { "<leader>jb", open_board, desc = "Jira Boards" },
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

    -- the snacks source tables are shared with snacks once registered, so patch them in place
    local sources = require("jira.picker.sources")

    local issues = sources.source_jira_issues
    issues.finder = issues_finder
    issues.jira_title = "JIRA Issues · " .. PROJECT
    issues.live = true
    issues.supports_live = true
    issues.win.input.title = "{title} {live}"
    add_toggles(issues, { "sprint", "genai" })

    local epics = sources.source_jira_epics
    epics.finder = epics_finder
    epics.jira_title = "JIRA Epics · " .. EPIC_PROJECT
    epics.live = true
    epics.supports_live = true
    add_toggles(epics, { "genai" })

    local epic_issues = sources.jira_epic_issues
    sources.jira_epic_issues = function(epic_key)
      local src = epic_issues(epic_key)
      src.finder = epic_issues_finder(epic_key)
      src.jira_title = "JIRA Epic Issues · " .. epic_key
      src.win.input.title = "{title}"
      return add_toggles(src, { "genai" })
    end

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
