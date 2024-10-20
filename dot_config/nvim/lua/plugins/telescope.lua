local replace_home = U.path.replace_home_with_tilde

local chezmoi_path = U.path.CHEZMOI
local config_path = U.path.CONFIG
local lazyvim_path = U.path.LAZYVIM

-- https://github.com/folke/dot/blob/master/nvim/lua/plugins/telescope.lua
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

local keys = {
  -- stylua: ignore
  { "<leader>fP", LazyVim.pick("files", { cwd = require("lazy.core.config").options.root }), desc = "Find Plugin File" },
  { "<leader>sP", pick_search_lazy_specs, desc = "Search Lazy Plugin Spec" },
  { "<leader>fL", pick_find_lazy_files, desc = "Find Lazy File" },
  { "<leader>sL", pick_search_lazy_codes, desc = "Search Lazy Code" },
  { "<leader>fB", pick_find_buffer_dir_files, desc = "Find Files (Buffer Dir)" },
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
        prompt_prefix = "", -- in favor of `p` on startup
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
            preview_cutoff = 20,
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
          }
          if chezmoi_path then
            table.insert(dir_icons, { chezmoi_path, "󰠦 " })
          end
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

  {
    "nvim-telescope/telescope.nvim",
    optional = true,
    dependencies = {
      {
        "danielfalk/smart-open.nvim",
        branch = "0.2.x",
        dependencies = {
          "kkharji/sqlite.lua",
          "nvim-telescope/telescope-fzf-native.nvim",
        },
      },
    },
    keys = {
      {
        "<leader>[", -- TODO: better keymap
        function()
          require("telescope").extensions.smart_open.smart_open({
            -- cwd_only = true, -- TODO: <leader>fF
            -- filename_first = false,
          })
        end,
        desc = "Smart Open",
      },
    },
    opts = function(_, opts)
      opts.extensions = vim.tbl_deep_extend("force", opts.extensions or {}, {
        smart_open = {
          match_algorithm = "fzf",
        },
      })

      LazyVim.on_load("telescope.nvim", function()
        require("telescope").setup(opts)
        require("telescope").load_extension("smart_open")
      end)
    end,
  },
}
