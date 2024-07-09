local Config = require("lazy.core.config")

local have_chezmoi = LazyVim.has_extra("util.chezmoi") and vim.fn.executable("chezmoi") == 1
local config_path = have_chezmoi and "~/.local/share/chezmoi/dot_config/nvim" or vim.fn.stdpath("config")
local lazyvim_path = Config.options.root .. "/LazyVim"

-- https://github.com/folke/dot/blob/master/nvim/lua/plugins/telescope.lua
local pick_find_plugin_files = function()
  local root = Config.options.root
  if LazyVim.pick.picker.name == "telescope" then
    require("telescope.builtin").find_files({ cwd = root })
  elseif LazyVim.pick.picker.name == "fzf" then
    require("fzf-lua").files({ cwd = root })
  end
end

local pick_search_lazy_specs = function()
  local dirs = { config_path .. "/lua/plugins", lazyvim_path .. "/lua/lazyvim/plugins" }
  if LazyVim.pick.picker.name == "telescope" then
    require("telescope.builtin").live_grep({
      default_text = "/",
      search_dirs = vim.tbl_values(dirs),
    })
  elseif LazyVim.pick.picker.name == "fzf" then
    require("fzf-lua").live_grep({
      filespec = "-- " .. table.concat(vim.tbl_values(dirs), " "),
      search = "/",
      formatter = "path.filename_first",
    })
  end
end

local pick_find_lazy_files = function()
  local dirs = { config_path .. "/lua", lazyvim_path .. "/lua" }
  if LazyVim.pick.picker.name == "telescope" then
    require("telescope.builtin").find_files({ search_dirs = dirs })
  elseif LazyVim.pick.picker.name == "fzf" then
    require("fzf-lua").files({ cmd = "rg --files " .. table.concat(vim.tbl_values(dirs), " ") })
  end
end

local pick_search_lazy_codes = function()
  local dirs = { config_path .. "/lua", lazyvim_path .. "/lua" }
  if LazyVim.pick.picker.name == "telescope" then
    require("telescope.builtin").live_grep({ search_dirs = vim.tbl_values(dirs) })
  elseif LazyVim.pick.picker.name == "fzf" then
    require("fzf-lua").live_grep({
      filespec = "-- " .. table.concat(vim.tbl_values(dirs), " "),
      formatter = "path.filename_first",
    })
  end
end

-- https://github.com/craftzdog/dotfiles-public/blob/master/.config/nvim/lua/plugins/editor.lua
local pick_find_buffer_dir_files = function()
  local buffer_dir = vim.fn.expand("%:p:h")
  if LazyVim.pick.picker.name == "telescope" then
    require("telescope.builtin").find_files({ cwd = buffer_dir })
  elseif LazyVim.pick.picker.name == "fzf" then
    require("fzf-lua").files({ cwd = buffer_dir })
  end
end

return {
  {
    "ibhagwan/fzf-lua",
    optional = true,
    keys = {
      { "<leader>fP", pick_find_plugin_files, desc = "Find Plugin File" },
      { "<leader>sP", pick_search_lazy_specs, desc = "Search Lazy Plugin Spec" },
      { "<leader>fL", pick_find_lazy_files, desc = "Find Lazy File" },
      { "<leader>sL", pick_search_lazy_codes, desc = "Search Lazy Code" },
      { "<leader>fB", pick_find_buffer_dir_files, desc = "Find Files (Buffer Dir)" },
    },
  },
  -- https://www.lazyvim.org/configuration/examples
  {
    "nvim-telescope/telescope.nvim",
    optional = true,
    keys = {
      { "<leader>fP", pick_find_plugin_files, desc = "Find Plugin File" },
      { "<leader>sP", pick_search_lazy_specs, desc = "Search Lazy Plugin Spec" },
      { "<leader>fL", pick_find_lazy_files, desc = "Find Lazy File" },
      { "<leader>sL", pick_search_lazy_codes, desc = "Search Lazy Code" },
      { "<leader>fB", pick_find_buffer_dir_files, desc = "Find Files (Buffer Dir)" },
    },
    opts = {
      defaults = {
        layout_strategy = "horizontal",
        layout_config = { prompt_position = "top" },
        sorting_strategy = "ascending",
        winblend = 0,
        -- ~/.local/share/nvim/lazy/telescope.nvim/lua/telescope/mappings.lua
        mappings = {
          n = {
            ["H"] = { "^", type = "command" },
            ["L"] = { "$", type = "command" },
          },
        },
      },
    },
  },
}
