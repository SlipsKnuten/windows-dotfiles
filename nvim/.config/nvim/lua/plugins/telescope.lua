local function project_picker()
  local pickers = require("telescope.pickers")
  local finders = require("telescope.finders")
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")
  local conf = require("telescope.config").values

  local projects_root = vim.fn.expand(vim.env.PROJECTS_DIR or "~/projects")
  if vim.fn.isdirectory(projects_root) == 0 then
    vim.notify("Projects folder not found: " .. projects_root, vim.log.levels.WARN)
    return
  end

  local projects = {}
  for name, type in vim.fs.dir(projects_root) do
    if type == "directory" then
      table.insert(projects, {
        name = name,
        path = vim.fs.joinpath(projects_root, name),
      })
    end
  end

  table.sort(projects, function(a, b)
    return a.name:lower() < b.name:lower()
  end)

  pickers
    .new({}, {
      prompt_title = "Projects",
      finder = finders.new_table({
        results = projects,
        entry_maker = function(project)
          return {
            value = project.path,
            display = project.name,
            ordinal = project.name .. " " .. project.path,
          }
        end,
      }),
      sorter = conf.generic_sorter({}),
      attach_mappings = function(prompt_bufnr)
        actions.select_default:replace(function()
          local entry = action_state.get_selected_entry()
          actions.close(prompt_bufnr)

          if not entry then
            return
          end

          vim.cmd("cd " .. vim.fn.fnameescape(entry.value))
          vim.schedule(function()
            require("telescope.builtin").find_files({ cwd = entry.value, hidden = true })
          end)
        end)
        return true
      end,
    })
    :find()
end

return {
  {
    "nvim-telescope/telescope.nvim",
    cmd = "Telescope",
    dependencies = { "nvim-lua/plenary.nvim" },
    keys = {
      { "<leader>pp", project_picker, desc = "Switch Project" },
      { "<C-p>", project_picker, desc = "Switch Project" },
    },
    opts = {
      defaults = {
        layout_strategy = "horizontal",
        layout_config = { prompt_position = "top" },
        sorting_strategy = "ascending",
        winblend = 0,
      },
    },
  },
}
