local function get_project_dirs(root)
  local projects = {}

  for name, type in vim.fs.dir(root) do
    if type == "directory" then
      table.insert(projects, vim.fs.joinpath(root, name))
    end
  end

  table.sort(projects, function(a, b)
    return vim.fs.basename(a):lower() < vim.fs.basename(b):lower()
  end)

  return projects
end

local function close_snacks_explorers()
  for _, picker in ipairs(Snacks.picker.get({ source = "explorer", tab = false })) do
    picker:close()
  end
end

local function open_project_picker()
  local root = vim.fn.expand(vim.env.PROJECTS_DIR or "~/projects")
  if vim.fn.isdirectory(root) == 0 then
    vim.notify("Projects folder not found: " .. root, vim.log.levels.WARN)
    return
  end

  Snacks.picker.projects({
    dev = { root },
    projects = get_project_dirs(root),
    recent = true,
    confirm = function(picker, item)
      picker:close()
      if not item then
        return
      end

      local path = item.file or item.text
      if not path then
        return
      end

      vim.cmd("tcd " .. vim.fn.fnameescape(path))
      vim.notify("Project: " .. vim.fn.fnamemodify(path, ":~"))
      vim.schedule(function()
        close_snacks_explorers()
        vim.cmd("Neotree focus filesystem left dir=" .. vim.fn.fnameescape(path))
      end)
    end,
  })
end

return {
  "folke/snacks.nvim",
  opts = {
    picker = {},
  },
  keys = {
    { "<leader>pp", open_project_picker, desc = "Switch Project" },
    { "<C-p>", open_project_picker, desc = "Switch Project" },
  },
}
