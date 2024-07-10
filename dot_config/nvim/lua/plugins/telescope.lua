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
        layout_config = {
          horizontal = {
            prompt_position = "top",
            preview_width = 0.5,
          },
          width = 0.8,
          height = 0.8,
          preview_cutoff = 120,
        },
        sorting_strategy = "ascending",
        winblend = 0,
        -- see `:help telescope.defaults.path_display`
        -- path_display = { "truncate" },
        -- path_display = { truncate = 1, "filename_first" },
        -- path_display = {
        --   "truncate",
        --   filename_first = {
        --     reverse_directories = true,
        --   },
        -- },
        path_display = function(opts, path)
          local transformed_path = vim.trim(require("util.path").replace_home_with_tilde(path))
          -- truncate
          -- copy from: https://github.com/nvim-telescope/telescope.nvim/blob/bfcc7d5c6f12209139f175e6123a7b7de6d9c18a/lua/telescope/utils.lua#L198
          -- ~/.local/share/nvim/lazy/telescope.nvim/lua/telescope/utils.lua
          -- https://github.com/babarot/dotfiles/blob/cab2b7b00aef87efdf068d910e5e02935fecdd98/.config/nvim/lua/plugins/telescope.lua#L5
          local truncate = require("plenary.strings").truncate
          local get_status = require("telescope.state").get_status
          local calc_result_length = function(truncate_len)
            local status = get_status(vim.api.nvim_get_current_buf())
            local len = vim.api.nvim_win_get_width(status.layout.results.winid)
              - status.picker.selection_caret:len()
              - 2
            return type(truncate_len) == "number" and len - truncate_len or len
          end
          -- local truncate_len = 1
          local truncate_len = nil
          if opts.__length == nil then
            opts.__length = calc_result_length(truncate_len)
          end
          if opts.__prefix == nil then
            opts.__prefix = 0
          end
          transformed_path = truncate(transformed_path, opts.__length - opts.__prefix, nil, -1)
          -- filename_first style
          local tail = require("telescope.utils").path_tail(path)
          local path_style = {
            { { 0, #transformed_path - #tail }, "Comment" }, -- Comment, TelescopeResultsComment
            -- { { #transformed_path - #tail, #transformed_path }, "Constant" },
          }
          return transformed_path, path_style
        end,
        -- ~/.local/share/nvim/lazy/telescope.nvim/lua/telescope/mappings.lua
        -- ~/.local/share/nvim/lazy/LazyVim/lua/lazyvim/plugins/extras/editor/telescope.lua
        mappings = {
          i = {
            -- same as <C-j> and <C-k> in fzf-lua
            -- ~/.local/share/nvim/lazy/LazyVim/lua/lazyvim/plugins/extras/editor/fzf.lua
            ["<C-j>"] = {
              require("telescope.actions").move_selection_next,
              type = "action",
              opts = { nowait = true, silent = true },
            },
            ["<C-k>"] = {
              require("telescope.actions").move_selection_previous,
              type = "action",
              opts = { nowait = true, silent = true },
            },
          },
          n = {
            ["H"] = { "^", type = "command" },
            ["L"] = { "$", type = "command" },
          },
        },
      },
    },
  },
}
