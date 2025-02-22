local H = {}

---@param text string
---@param width number
---@param direction? -1 | 1
function H.truncate(text, width, direction)
  if width <= 1 then
    return width == 1 and "…" or ""
  end
  local tw = vim.api.nvim_strwidth(text)
  if tw > width then
    return direction == -1 and "…" .. vim.fn.strcharpart(text, tw - width + 1, width - 1)
      or vim.fn.strcharpart(text, 0, width - 1) .. "…"
  end
  return text
end

function H.pick_search_lazy_specs()
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

function H.pick_find_plugin_files()
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

function H.pick_search_plugin_codes()
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

function H.pick_find_lazy_files()
  local dirs = { U.path.CONFIG .. "/lua", U.path.LAZYVIM .. "/lua" }
  if LazyVim.pick.picker.name == "telescope" then
    require("telescope.builtin").find_files({ search_dirs = dirs })
  elseif LazyVim.pick.picker.name == "fzf" then
    require("fzf-lua").files({ cmd = "rg --files " .. table.concat(vim.tbl_values(dirs), " ") })
  elseif LazyVim.pick.picker.name == "snacks" then
    Snacks.picker.files({ dirs = dirs })
  end
end

function H.pick_search_lazy_codes()
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
H.mappings = {
  { "<leader>sR", false },
  { "<leader>fP", H.pick_find_plugin_files, desc = "Find Plugin File" },
  { "<leader>sP", H.pick_search_plugin_codes, desc = "Search Plugin Code" },
  { "<leader>fL", H.pick_find_lazy_files, desc = "Find Lazy File" },
  { "<leader>sL", H.pick_search_lazy_codes, desc = "Search Lazy Code" },
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
          -- git
          { "<leader>gc", function() Snacks.picker.git_log({ cwd = LazyVim.root.git() }) end, desc = "Git Log" },
          { "<leader>gC", function() Snacks.picker.git_branches({ cwd = LazyVim.root.git() }) end, desc = "Git Branches" },
          { "<leader>gd", function() Snacks.picker.git_diff({ cwd = LazyVim.root.git() }) end, desc = "Git Diff (hunks)" },
          { "<leader>gs", function() Snacks.picker.git_status({ cwd = LazyVim.root.git() }) end, desc = "Git Status" },
          { "<leader>gS", function() Snacks.picker.git_stash({ cwd = LazyVim.root.git() }) end, desc = "Git Stash" },
          unpack(H.mappings),
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
          diff = {
            builtin = false,
            cmd = { "delta", "--file-style", "omit ", "--hunk-header-style", "omit" },
          },
          git = {
            builtin = false,
          },
        },
        on_show = function()
          vim.cmd("noh") -- clear_ui_esc
        end,
        sources = {
          files = {
            hidden = true,
            follow = true,
          },
          grep = {
            actions = {
              filter_extension = function(picker)
                local default = "*."
                Snacks.input.input({
                  prompt = "Filter By Extension",
                  default = default,
                }, function(glob)
                  glob = not vim.list_contains({ default, "" }, vim.trim(glob or "")) and glob or nil
                  local opts = picker.opts
                  ---@cast opts snacks.picker.grep.Config
                  -- see: https://github.com/folke/snacks.nvim/blob/bc902f7032df305df7dc48104cfa4e37967b3bdf/lua/snacks/picker/source/grep.lua#L57-L62
                  if opts.glob ~= glob then
                    opts.glob = glob
                    picker:find()
                  end
                end)
              end,
            },
            win = {
              input = {
                keys = {
                  ["<C-e>"] = { "filter_extension", mode = { "i", "n" } },
                },
              },
              list = {
                keys = {
                  ["<C-e>"] = { "filter_extension", mode = { "i", "n" } },
                },
              },
            },
          },
          lazy = {
            ---@diagnostic disable-next-line: missing-fields
            icons = {
              files = {
                enabled = false,
              },
            },
            format = function(item, picker)
              ---@type snacks.picker.Highlight[]
              local ret = {}

              local path = Snacks.picker.util.path(item) or item.file
              local icon, hl
              if path:find("lua/lazyvim/plugins/") then
                icon, hl = "󰒲 ", "MiniIconsBlue"
              else
                icon, hl = " ", "MiniIconsAzure"
              end
              ret[#ret + 1] = { icon, hl, virtual = true }

              -- copied from: https://github.com/folke/snacks.nvim/blob/b773368f8aa6e84a68e979f0e335d23de71f405a/lua/snacks/picker/format.lua#L118-L133
              vim.list_extend(ret, Snacks.picker.format.filename(item, picker))
              local trunc_len = 30
              for _, text in ipairs(ret) do
                if text[2] == "SnacksPickerDir" then
                  text[1] = text[1]:gsub("^.*lua/plugins/", ""):gsub("^.*lua/lazyvim/plugins/", "")
                  local offset = Snacks.picker.highlight.offset(ret, { char_idx = true })
                  text[1] = H.truncate(text[1], vim.api.nvim_strwidth(text[1]) - (offset - trunc_len) - 1, -1)
                  break
                end
              end

              if item.line then
                local offset = Snacks.picker.highlight.offset(ret, { char_idx = true })
                ret[#ret + 1] = { Snacks.picker.util.align(" ", trunc_len - offset) }
                Snacks.picker.highlight.format(item, vim.trim(item.line), ret)
                table.insert(ret, { " " })
              end
              return ret
            end,
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
              winbar = "", -- disable dropbar.nvim for Snacks.picker.buffers()
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
            },
          },
        },
      },
    },
  },
  {
    "folke/snacks.nvim",
    optional = true,
    opts = function()
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
          format = {
            file = 0,
            git_status = 3, -- https://github.com/folke/snacks.nvim/blob/48302be42f9c7035b70974cefe787e5410da3f3b/lua/snacks/picker/format.lua#L542-L543
            buffer = 7, -- https://github.com/folke/snacks.nvim/blob/48302be42f9c7035b70974cefe787e5410da3f3b/lua/snacks/picker/format.lua#L602-L605
            lsp_symbol = 40, -- https://github.com/folke/snacks.nvim/blob/48302be42f9c7035b70974cefe787e5410da3f3b/lua/snacks/picker/format.lua#L305-L305
          },
          source = {
            todo_comments = 9, -- https://github.com/folke/todo-comments.nvim/blob/304a8d204ee787d2544d8bc23cd38d2f929e7cc5/lua/todo-comments/snacks.lua#L34-L36
          },
        }
        local prefix = prefixes.format[picker.opts.format] or prefixes.source[picker.opts.source]
        if prefix then
          for _, text in ipairs(ret) do
            if text[2] ~= "SnacksPickerDir" then
              prefix = prefix + vim.api.nvim_strwidth(text[1])
            end
            if text[2] == "SnacksPickerFile" or text[2] == "SnacksPickerDirectory" then
              break
            end
          end
          dir_trunc_len = vim.api.nvim_win_get_width(picker.list.win.win) - prefix - 2
        end

        for _, text in ipairs(ret) do
          if text[2] == "SnacksPickerDir" then
            text[1] = U.path.shorten(text[1])
            text[1] = dir_trunc_len <= 1 and "" or H.truncate(text[1], dir_trunc_len, -1)
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
          lualine_x = { U.lualine.hlsearch }, -- clear_ui_esc
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
      { "<leader>sp", H.pick_search_lazy_specs, desc = "Search Lazy Plugin Spec" },
      unpack(H.mappings),
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

  {
    "nvim-telescope/telescope.nvim",
    optional = true,
    keys = {
      { "<leader>s.", "<cmd>Telescope resume<cr>", desc = "Resume" },
      { "<leader>ff", false },
      { "<leader>fF", false },
      unpack(H.mappings),
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
      -- fzf/snacks as picker and dressing.nvim as dependency of other plugins like avante.nvim
      return LazyVim.pick.picker.name == "telescope" and opts or U.extend_tbl(opts, { select = { enabled = false } })
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
}
