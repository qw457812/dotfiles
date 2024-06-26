local Config = require("lazy.core.config")

-- https://github.com/folke/dot/blob/master/nvim/lua/plugins/telescope.lua
-- ~/.local/share/nvim/lazy/LazyVim/lua/lazyvim/plugins/extras/util/project.lua
local pick_plugin = function()
  local root = Config.options.root
  if LazyVim.pick.picker.name == "telescope" then
    require("telescope.builtin").find_files({ cwd = root })
  elseif LazyVim.pick.picker.name == "fzf" then
    require("fzf-lua").files({ cwd = root })
  end
end

local pick_lazy_spec = function()
  local dirs = { "~/.config/nvim/lua/plugins", Config.options.root .. "/LazyVim/lua/lazyvim/plugins" }
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
local pick_buffer_dir = function()
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
      { "<leader>fP", pick_plugin, desc = "Find Plugin File" },
      { "<leader>sP", pick_lazy_spec, desc = "Search Lazy Plugin Spec" },
      { "<leader>F", pick_buffer_dir, desc = "Find Files (Buffer Dir)" },
    },
  },
  -- https://www.lazyvim.org/configuration/examples
  {
    "nvim-telescope/telescope.nvim",
    optional = true,
    keys = {
      { "<leader>fP", pick_plugin, desc = "Find Plugin File" },
      { "<leader>sP", pick_lazy_spec, desc = "Search Lazy Plugin Spec" },
      { "<leader>F", pick_buffer_dir, desc = "Find Files (Buffer Dir)" },
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
