local Config = require("lazy.core.config")

-- https://github.com/folke/dot/blob/master/nvim/lua/plugins/telescope.lua
local pick_plugin_files = function()
  local root = Config.options.root
  if LazyVim.pick.picker.name == "telescope" then
    require("telescope.builtin").find_files({ cwd = root })
  elseif LazyVim.pick.picker.name == "fzf" then
    require("fzf-lua").files({ cwd = root })
  end
end

local pick_lazy_specs = function()
  local dirs = {
    Config.options.root .. "/LazyVim/lua/lazyvim/plugins",
  }
  if LazyVim.has_extra("util.chezmoi") and vim.fn.executable("chezmoi") == 1 then
    table.insert(dirs, "~/.local/share/chezmoi/dot_config/nvim/lua/plugins")
  else
    table.insert(dirs, vim.fn.stdpath("config") .. "/lua/plugins")
  end
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

-- https://github.com/craftzdog/dotfiles-public/blob/master/.config/nvim/lua/plugins/editor.lua
local pick_buffer_dir_files = function()
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
      { "<leader>fP", pick_plugin_files, desc = "Find Plugin File" },
      { "<leader>sP", pick_lazy_specs, desc = "Search Lazy Plugin Spec" },
      { "<leader>fB", pick_buffer_dir_files, desc = "Find Files (Buffer Dir)" },
    },
  },
  -- https://www.lazyvim.org/configuration/examples
  {
    "nvim-telescope/telescope.nvim",
    optional = true,
    keys = {
      { "<leader>fP", pick_plugin_files, desc = "Find Plugin File" },
      { "<leader>sP", pick_lazy_specs, desc = "Search Lazy Plugin Spec" },
      { "<leader>fB", pick_buffer_dir_files, desc = "Find Files (Buffer Dir)" },
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
