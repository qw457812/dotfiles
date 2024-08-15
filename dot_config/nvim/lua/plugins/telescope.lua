local Config = require("lazy.core.config")
local replace_home = require("util.path").replace_home_with_tilde

local have_chezmoi = LazyVim.has_extra("util.chezmoi") and vim.fn.executable("chezmoi") == 1
local chezmoi_source_path = "~/.local/share/chezmoi"
local config_path = have_chezmoi and chezmoi_source_path .. "/dot_config/nvim" or vim.fn.stdpath("config") --[[@as string]]
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

local pick_colorschemes = function()
  if LazyVim.pick.picker.name == "telescope" then
    local colors = {}
    -- :=vim.g.colors_name
    if LazyVim.has("tokyonight.nvim") then
      vim.list_extend(colors, {
        -- "tokyonight-day", -- light
        -- "tokyonight", -- same as `tokyonight-moon`
        "tokyonight-moon",
        "tokyonight-storm",
        "tokyonight-night",
      })
    end
    if LazyVim.has("catppuccin") then
      vim.list_extend(colors, {
        -- "catppuccin-latte", -- light
        "catppuccin-frappe",
        "catppuccin-macchiato",
        -- "catppuccin", -- same as `catppuccin-mocha`
        "catppuccin-mocha",
      })
    end
    require("telescope.builtin").colorscheme({
      colors = colors,
      enable_preview = true,
      ignore_builtins = true,
    })
  elseif LazyVim.pick.picker.name == "fzf" then
    require("fzf-lua").colorschemes()
  end
end

local keys = {
  { "<leader>fP", pick_find_plugin_files, desc = "Find Plugin File" },
  { "<leader>sP", pick_search_lazy_specs, desc = "Search Lazy Plugin Spec" },
  { "<leader>fL", pick_find_lazy_files, desc = "Find Lazy File" },
  { "<leader>sL", pick_search_lazy_codes, desc = "Search Lazy Code" },
  { "<leader>fB", pick_find_buffer_dir_files, desc = "Find Files (Buffer Dir)" },
  { "<leader>uC", pick_colorschemes, desc = "Colorscheme with Preview" },
}

return {
  {
    "ibhagwan/fzf-lua",
    optional = true,
    keys = keys,
  },
  -- https://www.lazyvim.org/configuration/examples
  {
    "nvim-telescope/telescope.nvim",
    optional = true,
    keys = keys,
    opts = {
      defaults = {
        layout_strategy = vim.g.user_is_termux and "vertical" or "horizontal",
        layout_config = {
          horizontal = {
            width = 0.8,
            height = 0.8,
            prompt_position = "top",
            preview_cutoff = 120,
            preview_width = 0.5,
          },
          vertical = {
            width = function(_, max_columns, _)
              return vim.g.user_is_termux and max_columns or math.floor(max_columns * 0.8)
            end,
            height = function(_, _, max_lines)
              return vim.g.user_is_termux and max_lines or math.floor(max_lines * 0.8)
            end,
            preview_cutoff = 30,
            preview_height = function(_, _, max_lines)
              return math.max(max_lines - 12, math.floor(max_lines * 0.6))
            end,
          },
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
          local transformed_path = vim.trim(replace_home(path))
          -- make path shorter
          local dir_icons = {
            { config_path, " " },
            { lazyvim_path, "󰒲 " },
            { chezmoi_source_path, "󰠦 " },
          }
          for _, dir_icon in ipairs(dir_icons) do
            transformed_path = transformed_path:gsub("^" .. vim.pesc(replace_home(dir_icon[1])) .. "/", dir_icon[2])
          end
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
          -- highlight group: Comment, TelescopeResultsComment, Constant, TelescopeResultsNumber, TelescopeResultsIdentifier
          local path_style = {
            { { 0, #transformed_path - #tail }, "Comment" },
            -- { { #transformed_path - #tail, #transformed_path }, "TelescopeResultsIdentifier" },
            { { #transformed_path, 999 }, "TelescopeResultsComment" },
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
