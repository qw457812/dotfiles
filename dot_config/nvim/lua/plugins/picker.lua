-- https://github.com/folke/dot/blob/master/nvim/lua/plugins/telescope.lua
local pick_search_lazy_specs = function()
  local dirs = { U.path.CONFIG .. "/lua/plugins", U.path.LAZYVIM .. "/lua/lazyvim/plugins" }
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
  elseif LazyVim.pick.picker.name == "snacks" then
    Snacks.picker.grep({ search = "/", dirs = dirs })
  end
end

-- alternative: https://github.com/tsakirist/telescope-lazy.nvim
local pick_find_plugin_files = function()
  if LazyVim.pick.picker.name == "telescope" then
    -- https://github.com/chrisgrieser/.config/blob/41c33a44e9c02bd04ea7cedcaed0f5547129e83c/nvim/lua/config/lazy.lua#L170
    vim.ui.select(require("lazy").plugins(), {
      prompt = "Select Plugin",
      format_item = function(plugin)
        return plugin.name
      end,
    }, function(plugin)
      if not plugin then
        return
      end
      LazyVim.pick("files", { cwd = plugin.dir, prompt_title = plugin.name })()
    end)
  elseif vim.list_contains({ "fzf", "snacks" }, LazyVim.pick.picker.name) then
    LazyVim.pick("files", { cwd = require("lazy.core.config").options.root })()
  end
end

local pick_search_plugin_codes = function()
  if LazyVim.pick.picker.name == "telescope" then
    vim.ui.select(require("lazy").plugins(), {
      prompt = "Select Plugin",
      format_item = function(plugin)
        return plugin.name
      end,
    }, function(plugin)
      if not plugin then
        return
      end
      LazyVim.pick("live_grep", { cwd = plugin.dir, prompt_title = plugin.name })()
    end)
  elseif vim.list_contains({ "fzf", "snacks" }, LazyVim.pick.picker.name) then
    LazyVim.pick("live_grep", { cwd = require("lazy.core.config").options.root })()
  end
end

local pick_find_lazy_files = function()
  local dirs = { U.path.CONFIG .. "/lua", U.path.LAZYVIM .. "/lua" }
  if LazyVim.pick.picker.name == "telescope" then
    require("telescope.builtin").find_files({ search_dirs = dirs })
  elseif LazyVim.pick.picker.name == "fzf" then
    require("fzf-lua").files({ cmd = "rg --files " .. table.concat(vim.tbl_values(dirs), " ") })
  elseif LazyVim.pick.picker.name == "snacks" then
    Snacks.picker.files({ dirs = dirs })
  end
end

local pick_search_lazy_codes = function()
  local dirs = { U.path.CONFIG .. "/lua", U.path.LAZYVIM .. "/lua" }
  if LazyVim.pick.picker.name == "telescope" then
    require("telescope.builtin").live_grep({ search_dirs = vim.tbl_values(dirs) })
  elseif LazyVim.pick.picker.name == "fzf" then
    require("fzf-lua").live_grep({
      filespec = "-- " .. table.concat(vim.tbl_values(dirs), " "),
      formatter = "path.filename_first",
    })
  elseif LazyVim.pick.picker.name == "snacks" then
    Snacks.picker.grep({ dirs = dirs })
  end
end

-- stylua: ignore
local mappings = {
  { "<leader>sR", false },
  { "<leader>fP", pick_find_plugin_files, desc = "Find Plugin File" },
  { "<leader>sP", pick_search_plugin_codes, desc = "Search Plugin Code" },
  { "<leader>fL", pick_find_lazy_files, desc = "Find Lazy File" },
  { "<leader>sL", pick_search_lazy_codes, desc = "Search Lazy Code" },
  -- { "<leader>fB", function() LazyVim.pick("files", { cwd = vim.fn.expand("%:p:h") })() end, desc = "Find Files (Buffer Dir)" },
  { "<leader>sB", function() LazyVim.pick("live_grep", { cwd = vim.fn.expand("%:p:h") })() end, desc = "Grep (Buffer Dir)" },
}

return {
  {
    "folke/snacks.nvim",
    keys = function(_, keys)
      if LazyVim.pick.picker.name == "snacks" then
        -- stylua: ignore
        vim.list_extend(keys, {
          { "<leader>s.", function() Snacks.picker.resume() end, desc = "Resume" },
          { "<leader>ff", function() Snacks.picker.smart() end, desc = "Smart" },
          { "<leader>fF", function() Snacks.picker.files({ hidden = true, follow = true, ignored = true }) end, desc = "Find all files" },
          { "<leader>gC", function() Snacks.picker.git_branches() end, desc = "Git branches" },
          unpack(mappings),
        })
      end
    end,
    ---@module "snacks"
    ---@type snacks.Config
    opts = {
      picker = {
        layout = {
          cycle = false,
          preset = function()
            return vim.o.columns >= 120 and "default" or "narrow"
          end,
        },
        layouts = {
          narrow = {
            layout = {
              backdrop = false,
              width = 0.5,
              min_width = 80,
              height = 0.8,
              min_height = 30,
              border = "none",
              box = "vertical",
              { win = "preview", title = "{preview}", height = 0.4, border = "rounded" },
              {
                box = "vertical",
                border = "rounded",
                title = "{title} {live} {flags}",
                title_pos = "center",
                { win = "input", height = 1, border = "bottom" },
                { win = "list", border = "none" },
              },
            },
          },
        },
        previewers = {
          git = {
            native = true,
          },
        },
        sources = {
          files = {
            hidden = true,
            follow = true,
          },
        },
        win = {
          input = {
            keys = {
              -- use the same `["<Esc>"]` key to ensure overwriting
              ["<Esc>"] = { "<Esc>", U.keymap.clear_ui_esc, desc = "Clear UI or Close" },
              ["/"] = false, -- highlights text in preview
              ["<leader><space>"] = "toggle_focus",
              ["<leader><tab>"] = "cycle_win", -- toggle focus between input and preview
              ["<Up>"] = "history_back",
              ["<Down>"] = "history_forward",
              i_up = { "<Up>", "list_up", mode = "i", expr = true },
              i_down = { "<Down>", "list_down", mode = "i", expr = true },
              ["<Left>"] = "preview_scroll_left",
              ["<Right>"] = "preview_scroll_right",
              ["<C-Left>"] = { "preview_scroll_left", mode = { "i", "n" } },
              ["<C-Right>"] = { "preview_scroll_right", mode = { "i", "n" } },
            },
          },
          list = {
            keys = {
              ["<Esc>"] = {
                "<Esc>",
                function(self)
                  if not U.keymap.clear_ui_esc({ close = false }) then
                    self:execute("toggle_focus")
                  end
                end,
                desc = "Clear UI or Toggle Focus",
              },
              ["/"] = false,
              ["<leader><space>"] = "toggle_focus",
              -- TODO: <leader><tab> to focus preview
              ["<Left>"] = "preview_scroll_left",
              ["<Right>"] = "preview_scroll_right",
              ["<C-Left>"] = "preview_scroll_left",
              ["<C-Right>"] = "preview_scroll_right",
            },
          },
          preview = {
            wo = {
              signcolumn = "no",
              number = false,
            },
            keys = {
              ["<Esc>"] = {
                "<Esc>",
                function(self)
                  if not U.keymap.clear_ui_esc({ close = false }) then
                    self:execute("toggle_focus")
                  end
                end,
                desc = "Clear UI or Toggle Focus",
              },
              ["<leader><tab>"] = "toggle_focus",
              -- TODO: <leader><space> to focus list
            },
          },
        },
      },
    },
  },
  {
    "folke/snacks.nvim",
    optional = true,
    opts = function(_, opts)
      ---@param text string
      ---@param width number
      ---@param direction? -1 | 1
      local function truncate(text, width, direction)
        local tw = vim.api.nvim_strwidth(text)
        if tw > width then
          return direction == -1 and "…" .. vim.fn.strcharpart(text, tw - width + 1, width - 1)
            or vim.fn.strcharpart(text, 0, width - 1) .. "…"
        end
        return text
      end

      -- HACK: shorten & truncate dir | https://github.com/folke/snacks.nvim/blob/2568f18c4de0f43b15b0244cd734dcb5af93e53f/lua/snacks/picker/format.lua#L51
      Snacks.picker.util.truncpath = function(path)
        return path
      end
      local filename_orig = Snacks.picker.format.filename
      Snacks.picker.format.filename = function(item, picker)
        local ret = filename_orig(item, picker)
        if picker.opts.formatters.file.filename_only then
          return ret
        end

        local dir_trunc_len = 40
        local prefixes = {
          file = 0,
          git_status = 3,
          buffer = 7, -- see: https://github.com/folke/snacks.nvim/blob/2568f18c4de0f43b15b0244cd734dcb5af93e53f/lua/snacks/picker/format.lua#L461-L464
          lsp_symbol = 40,
        }
        if vim.tbl_contains(vim.tbl_keys(prefixes), picker.opts.format) then
          local prefix = 0
          for _, text in ipairs(ret) do
            if text[2] ~= "SnacksPickerDir" then
              prefix = prefix + vim.api.nvim_strwidth(text[1])
            end
            if text[2] == "SnacksPickerFile" or text[2] == "SnacksPickerDirectory" then
              break
            end
          end
          dir_trunc_len = vim.api.nvim_win_get_width(picker.list.win.win) - prefix - prefixes[picker.opts.format] - 2
        end

        for _, text in ipairs(ret) do
          if text[2] == "SnacksPickerDir" then
            text[1] = U.path.shorten(text[1])
            text[1] = dir_trunc_len <= 1 and "" or truncate(text[1], dir_trunc_len, -1)
            break
          end
        end
        return ret
      end
    end,
  },

  {
    "nvim-lualine/lualine.nvim",
    optional = true,
    opts = function(_, opts)
      if LazyVim.pick.picker.name ~= "snacks" then
        return
      end

      local snacks_picker = {
        sections = {
          lualine_a = not vim.g.user_is_termux and {
            function()
              return "snacks"
            end,
          } or nil,
          lualine_b = not vim.g.user_is_termux
              and {
                function()
                  local picker = Snacks.picker.get()[1]
                  -- return picker and picker.list.cursor .. "/" .. picker.input.totals or ""
                  return picker and picker.list.cursor .. "/" .. picker.list:count() or ""
                end,
              }
            or nil,
          lualine_x = { U.lualine.hlsearch }, -- esc
          lualine_y = {
            function()
              local picker = Snacks.picker.get()[1]
              local item = picker and picker:current()
              -- local path = item and item.file -- better performance
              local path = item and Snacks.picker.util.path(item)
              return path and U.path.shorten(path) or ""
            end,
          },
          lualine_z = {
            function()
              local picker = Snacks.picker.get()[1]
              return picker and picker.opts.source or "custom"
            end,
          },
        },
        filetypes = { "snacks_picker_input" }, -- snacks_picker_list snacks_picker_preview
      }

      table.insert(opts.extensions, snacks_picker)
    end,
  },

  {
    "ibhagwan/fzf-lua",
    optional = true,
    keys = {
      { "<leader>s.", "<cmd>FzfLua resume<cr>", desc = "Resume" },
      { "<leader>sp", pick_search_lazy_specs, desc = "Search Lazy Plugin Spec" },
      unpack(mappings),
    },
    opts = {
      -- defaults = {
      --   formatter = "path.filename_first",
      --   -- formatter = { "path.filename_first", 2 },
      -- },
      winopts = {
        width = vim.g.user_is_termux and 1 or nil,
        height = vim.g.user_is_termux and 1 or nil,
        preview = {
          horizontal = "right:50%",
        },
      },
      fzf_opts = {
        ["--ellipsis"] = "…",
        -- ["--keep-right"] = "",
      },
      previewers = {
        codeaction_native = {
          pager = [[delta --width=$COLUMNS --hunk-header-style="omit" --file-style="omit"]],
        },
      },
      -- files = { path_shorten = vim.g.user_is_termux and 10 or 20 },
      -- grep = { path_shorten = vim.g.user_is_termux and 10 or 20 },
      -- buffers = { path_shorten = vim.g.user_is_termux and 10 or 20 },
    },
  },

  -- https://www.lazyvim.org/configuration/examples
  {
    "nvim-telescope/telescope.nvim",
    optional = true,
    keys = {
      { "<leader>s.", "<cmd>Telescope resume<cr>", desc = "Resume" },
      { "<leader>ff", false },
      { "<leader>fF", false },
      unpack(mappings),
    },
    opts = {
      defaults = {
        prompt_prefix = "", -- in favor of `p` in normal mode on startup
        -- layout_strategy = vim.g.user_is_termux and "vertical" or "horizontal",
        layout_strategy = "flex",
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
            preview_height = 0.5,
          },
        },
        sorting_strategy = "ascending",
        winblend = 0,
        -- -- see `:help telescope.defaults.path_display`
        -- path_display = { "truncate" },
        -- path_display = { truncate = 1, "filename_first" },
        -- path_display = { "truncate", filename_first = { reverse_directories = true } },
        path_display = U.telescope.path_display,
        mappings = {
          i = {
            ["<C-j>"] = "move_selection_next",
            ["<C-k>"] = "move_selection_previous",
            ["<C-u>"] = U.telescope.actions.results_half_page_up,
            ["<C-d>"] = U.telescope.actions.results_half_page_down,
            ["<C-Left>"] = "preview_scrolling_left",
            ["<C-Right>"] = "preview_scrolling_right",
            ["<M-Left>"] = "results_scrolling_left",
            ["<M-Right>"] = "results_scrolling_right",
          },
          n = {
            ["H"] = { "^", type = "command" },
            ["L"] = { "$", type = "command" },
            ["<C-j>"] = "move_selection_next",
            ["<C-k>"] = "move_selection_previous",
            ["<C-u>"] = U.telescope.actions.results_half_page_up,
            ["<C-d>"] = U.telescope.actions.results_half_page_down,
            ["<C-f>"] = "preview_scrolling_down",
            ["<C-b>"] = "preview_scrolling_up",
            ["<Down>"] = "cycle_history_next",
            ["<Up>"] = "cycle_history_prev",
            ["<C-Down>"] = "cycle_history_next",
            ["<C-Up>"] = "cycle_history_prev",
            ["<Left>"] = "preview_scrolling_left",
            ["<Right>"] = "preview_scrolling_right",
            ["<C-Left>"] = "preview_scrolling_left",
            ["<C-Right>"] = "preview_scrolling_right",
            ["<M-Left>"] = "results_scrolling_left",
            ["<M-Right>"] = "results_scrolling_right",
          },
        },
      },
    },
  },
  {
    "stevearc/dressing.nvim",
    optional = true,
    opts = function(_, opts)
      -- we have snacks input
      opts = U.extend_tbl(opts, { input = { enabled = false } })
      -- fzf as picker and dressing.nvim as dependency of other plugins like avante.nvim
      return LazyVim.pick.want() == "telescope" and opts or U.extend_tbl(opts, { select = { enabled = false } })
    end,
  },

  -- alternative: https://github.com/chrisgrieser/.config/blob/88eb71f88528f1b5a20b66fd3dfc1f7bd42b408a/nvim/lua/config/lazy.lua#L129
  {
    "nvim-telescope/telescope.nvim",
    optional = true,
    dependencies = {
      {
        "polirritmico/telescope-lazy-plugins.nvim",
        -- lazy loading | https://github.com/polirritmico/telescope-lazy-plugins.nvim/blob/main/README.md?plain=1#L273
        init = function()
          LazyVim.on_load("telescope.nvim", function()
            require("telescope").load_extension("lazy_plugins")
          end)
        end,
      },
    },
    keys = {
      { "<leader>sp", "<Cmd>Telescope lazy_plugins<CR>", desc = "Search Lazy Plugin Spec" },
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
        "<leader>ff",
        function()
          require("telescope").extensions.smart_open.smart_open({
            -- filename_first = false,
          })
        end,
        desc = "Smart Open",
      },
      {
        "<leader>fF",
        function()
          require("telescope").extensions.smart_open.smart_open({
            cwd_only = true,
            -- filename_first = false,
          })
        end,
        desc = "Smart Open (cwd)",
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

  -- {
  --   "piersolenski/telescope-import.nvim",
  --   enabled = function()
  --     return LazyVim.has("telescope.nvim")
  --   end,
  --   keys = {
  --     { "<leader>ci", "<cmd>Telescope import<cr>", desc = "Pick Import" },
  --   },
  --   config = function()
  --     LazyVim.on_load("telescope.nvim", function()
  --       require("telescope").load_extension("import")
  --     end)
  --   end,
  -- },
}
