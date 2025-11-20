local H = {}

local SCROLL_UP, SCROLL_DOWN = vim.keycode("<c-u>"), vim.keycode("<c-d>")

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
  { "<leader>fP", H.pick_find_plugin_files, desc = "Plugin File" },
  { "<leader>sP", H.pick_search_plugin_codes, desc = "Plugin Code" },
  { "<leader>f,", H.pick_find_lazy_files, desc = "LazyVim File" },
  { "<leader>s,", H.pick_search_lazy_codes, desc = "LazyVim Code" },
  -- { "<leader>fB", function() LazyVim.pick("files", { cwd = vim.fn.expand("%:p:h") })() end, desc = "Find Files (Buffer Dir)" },
  -- { "<leader>sB", function() LazyVim.pick("live_grep", { cwd = vim.fn.expand("%:p:h") })() end, desc = "Grep (Buffer Dir)" },
}

---@type LazySpec
return {
  {
    "folke/snacks.nvim",
    keys = function(_, keys)
      if LazyVim.pick.picker.name == "snacks" then
        -- stylua: ignore
        vim.list_extend(keys, {
          { "<leader>s.", function() Snacks.picker.resume() end, desc = "Resume" },
          { "<leader>,", function() Snacks.picker.buffers({ current = false }) end, desc = "Buffers" },
          { "<leader>fC", function() Snacks.picker.buffers({ modified = true }) end, desc = "Buffers (changed)" },
          { "<leader>fa", function() Snacks.picker.files({ hidden = true, follow = true, ignored = true, cwd = LazyVim.root() }) end, desc = "Find All Files (Root Dir)" },
          { "<leader>fA", function() Snacks.picker.files({ hidden = true, follow = true, ignored = true }) end, desc = "Find All Files (cwd)" },
          { "<leader>sA", function() Snacks.picker() end, desc = "All Pickers" },
          unpack(H.mappings),
        })
      end
      return keys
    end,
    ---@module "snacks"
    ---@type snacks.Config
    opts = {
      picker = {
        prompt = "  ",
        layout = {
          cycle = false,
          preset = function()
            -- vim.o.columns > 2 * vim.o.lines
            local layouts = vim.o.columns >= 120 and { "default", "based_telescope", "borderless", "based_borderless" }
              or { "narrow", "borderless_narrow", "based_borderless_narrow" }
            return layouts[math.random(#layouts)]
          end,
        },
        -- copied from: https://github.com/folke/snacks.nvim/blob/27cba535a6763cbca3f3162c5c4bb48c6f382005/lua/snacks/picker/config/layouts.lua
        layouts = {
          based_telescope = {
            layout = {
              box = "horizontal",
              backdrop = false,
              width = 0.8,
              height = 0.8,
              border = "none",
              {
                box = "vertical",
                {
                  win = "input",
                  height = 1,
                  border = "rounded",
                  title = "{title} {live} {flags}",
                  title_pos = "center",
                },
                { win = "list", title = " Results ", title_pos = "center", border = "rounded" },
              },
              {
                win = "preview",
                title = "{preview:Preview}",
                width = 0.5,
                border = "rounded",
                title_pos = "center",
              },
            },
          },
          -- based on the dropdown preset, mainly for termux
          narrow = {
            layout = {
              backdrop = false,
              width = 0.5,
              min_width = 80,
              height = 0.8,
              min_height = math.min(35, vim.o.lines - 1), -- 1 for lualine.nvim
              border = "none",
              box = "vertical",
              { win = "preview", title = "{preview}", height = 0.45, border = "rounded" },
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
          -- based on the default preset
          -- see also: https://github.com/folke/snacks.nvim/blob/fa29c6c92631026a7ee41249c78bd91562e67a09/lua/snacks/win.lua#L186-L191
          borderless = {
            layout = {
              box = "horizontal",
              width = 0.8,
              min_width = 120,
              height = 0.8,
              border = "none",
              {
                box = "vertical",
                border = "solid",
                title = "{title} {live} {flags}",
                { win = "input", height = 1, border = { "", "", "", "", "", " ", "", "" } },
                { win = "list", border = "none" },
              },
              { win = "preview", title = "{preview}", border = "solid", width = 0.5 },
            },
          },
          -- based on the narrow layout
          borderless_narrow = {
            layout = {
              backdrop = false,
              width = 0.5,
              min_width = 80,
              height = 0.8,
              min_height = math.min(35, vim.o.lines - 1),
              border = "none",
              box = "vertical",
              { win = "preview", title = "{preview}", height = 0.45, border = "solid" },
              {
                box = "vertical",
                border = "solid",
                title = "{title} {live} {flags}",
                title_pos = "center",
                { win = "input", height = 1, border = { "", "", "", "", "", " ", "", "" } },
                { win = "list", border = "none" },
              },
            },
          },
          -- add a few borders to split input, list and preview
          based_borderless = {
            layout = {
              box = "horizontal",
              width = 0.8,
              min_width = 120,
              height = 0.8,
              border = "none",
              {
                box = "vertical",
                border = "solid",
                title = "{title} {live} {flags}",
                { win = "input", height = 1, border = "bottom" },
                { win = "list", border = "none" },
              },
              {
                win = "preview",
                title = "{preview}",
                border = { " ", " ", " ", " ", " ", " ", " ", "│" },
                width = 0.5,
              },
            },
          },
          based_borderless_narrow = {
            layout = {
              backdrop = false,
              width = 0.5,
              min_width = 80,
              height = 0.8,
              min_height = math.min(35, vim.o.lines - 1),
              border = "none",
              box = "vertical",
              { win = "preview", title = "{preview}", height = 0.45, border = "solid" },
              {
                box = "vertical",
                border = { " ", "─", " ", " ", " ", " ", " ", " " },
                title = "{title} {live} {flags}",
                title_pos = "center",
                { win = "input", height = 1, border = "bottom" },
                { win = "list", border = "none" },
              },
            },
          },
        },
        on_show = function()
          -- in favor of clear_ui_esc
          vim.cmd("noh")
          vim.g.user_suppress_lsp_progress = true
          if package.loaded["noice"] then
            require("noice").cmd("dismiss")
          end
        end,
        on_close = function()
          vim.g.user_suppress_lsp_progress = nil
        end,
        actions = {
          -- do not allow scrolling beyond eob, see:
          -- - https://github.com/folke/snacks.nvim/commit/8b5f76292becf9ad76ef1507cbdcec64a49ff3f4
          -- - https://github.com/folke/snacks.nvim/commit/a2716102c8bd7d25693201af0942552f10e9a0c3
          preview_down = function(picker)
            if picker.preview.win:valid() then
              vim.api.nvim_win_call(picker.preview.win.win, function()
                vim.cmd(("normal! %s"):format(SCROLL_DOWN))
              end)
            end
          end,
          preview_up = function(picker)
            if picker.preview.win:valid() then
              vim.api.nvim_win_call(picker.preview.win.win, function()
                vim.cmd(("normal! %s"):format(SCROLL_UP))
              end)
            end
          end,
          -- ref: https://github.com/folke/snacks.nvim/blob/df018edfdbc5df832b46b9bdc9eafb1d69ea460b/lua/snacks/picker/core/list.lua#L428-L430
          unselect_all = function(picker)
            picker.list:set_selected({})
          end,
          reveal_file = function(_, item)
            local path = item and Snacks.picker.util.path(item)
            if path then
              U.reveal_file(path)
            else
              LazyVim.warn("Not a file", { title = "Reveal" })
            end
          end,
          toggle_lua = function(p)
            local opts = p.opts --[[@as snacks.picker.grep.Config]]
            opts.ft = not opts.ft and "lua" or nil
            p:find()
          end,
          -- for sources: grep, files
          filter_extension = function(picker)
            local mode = vim.fn.mode()
            local is_grep = vim.list_contains({ "grep", "grep_word" }, picker.opts.source)
            local default = is_grep and "*." or ""
            Snacks.input.input({
              prompt = "Filter By Extension",
              default = default,
            }, function(ext)
              ext = not vim.list_contains({ default, "" }, vim.trim(ext or "")) and ext or nil
              local opts = picker.opts
              if is_grep then
                ---@cast opts snacks.picker.grep.Config
                -- see: https://github.com/folke/snacks.nvim/blob/bc902f7032df305df7dc48104cfa4e37967b3bdf/lua/snacks/picker/source/grep.lua#L57-L62
                if opts.glob ~= ext then
                  opts.glob = ext
                  picker:find()
                end
              else
                ---@cast opts snacks.picker.files.Config
                -- see: https://github.com/folke/snacks.nvim/blob/bc902f7032df305df7dc48104cfa4e37967b3bdf/lua/snacks/picker/source/files.lua#L75-L90
                if opts.ft ~= ext then
                  opts.ft = ext
                  picker:find()
                end
              end
              if mode == "n" then
                vim.cmd.stopinsert()
              end
            end)
          end,
        },
        sources = {
          files = {
            hidden = true,
            follow = true,
          },
          grep = {
            hidden = true,
          },
          grep_word = {
            hidden = true,
          },
          lazy = {
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
              -- TODO: adapt to latest changes in snacks.nvim
              -- - check `Snacks.picker.highlight.resolve`
              -- - https://github.com/folke/snacks.nvim/blob/5173e96f3359121233e817c12307d531a8622e4f/lua/snacks/picker/format.lua#L162-L177
              vim.list_extend(ret, Snacks.picker.format.filename(item, picker))
              local trunc_len = 30
              for _, text in ipairs(ret) do
                if text[2] == "SnacksPickerDir" then
                  text[1] = text[1]:gsub("^.*lua/plugins/", ""):gsub("^.*lua/lazyvim/plugins/", "")
                  local offset = Snacks.picker.highlight.offset(ret, { char_idx = true })
                  text[1] = U.truncate(text[1], vim.api.nvim_strwidth(text[1]) - (offset - trunc_len) - 1, -1)
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
          highlights = {
            confirm = function(picker, item)
              picker:close()
              if item then
                vim.fn.setreg(vim.v.register, item.hl_group)
                LazyVim.info(item.hl_group, { title = "Copied Highlight Group" })
              end
            end,
          },
          ---@type snacks.picker.icons.Config
          icons = {
            icon_sources = { "nerd_fonts" }, -- disable emoji
            confirm = { "copy", "close" },
          },
        },
        win = {
          input = {
            keys = {
              -- use the same `["<Esc>"]` key to ensure overwriting
              ["<Esc>"] = {
                "<Esc>",
                function(self)
                  if U.keymap.clear_ui_esc({ close = false }) then
                    return
                  end
                  local picker = assert(Snacks.picker.get()[1])
                  -- use `cancel` instead of `close` to go back to last window
                  -- for example: prevent neo-tree from gaining focus when closing the snacks picker while in a jdtls class buffer
                  self:execute(#picker.list.selected > 0 and "unselect_all" or "cancel")
                end,
                desc = "Clear UI or Close",
              },
              ["J"] = "preview_down", -- same as lazygit/yazi
              ["K"] = "preview_up",
              ["<PageDown>"] = { "preview_scroll_down", mode = { "i", "n" } },
              ["<PageUp>"] = { "preview_scroll_up", mode = { "i", "n" } },
              ["o"] = "confirm",
              ["/"] = false, -- highlights text in preview
              ["<C-e>"] = { "filter_extension", mode = { "i", "n" } },
              ["<M-l>"] = { "toggle_lua", mode = { "n", "i" } },
              ["<C-Space>"] = { "cycle_win", mode = { "n", "i" } },
              ["<C-,>"] = "toggle_input",
              i_ctrl_comma = {
                "<C-,>",
                function(self)
                  vim.cmd.stopinsert()
                  vim.schedule(function()
                    self:execute("toggle_input")
                  end)
                end,
                mode = "i",
                desc = "toggle_input",
              },
              ["<Up>"] = "history_back",
              ["<Down>"] = "history_forward",
              i_up = { "<Up>", "list_up", mode = "i", expr = true },
              i_down = { "<Down>", "list_down", mode = "i", expr = true },
              ["<C-h>"] = { "preview_scroll_left", mode = { "i", "n" } },
              ["<C-l>"] = { "preview_scroll_right", mode = { "i", "n" } },
              ["<Left>"] = "preview_scroll_left",
              ["<Right>"] = "preview_scroll_right",
              ["<C-Left>"] = { "preview_scroll_left", mode = { "i", "n" } },
              ["<C-Right>"] = { "preview_scroll_right", mode = { "i", "n" } },
              ["<localleader>o"] = "reveal_file",
              ["<leader>fO"] = "reveal_file",
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
                desc = "Clear UI or Focus Input",
              },
              ["J"] = "preview_down",
              ["K"] = "preview_up",
              ["<PageDown>"] = "preview_scroll_down",
              ["<PageUp>"] = "preview_scroll_up",
              ["o"] = "confirm",
              ["/"] = false,
              ["<C-e>"] = "filter_extension",
              ["<M-l>"] = "toggle_lua",
              ["<C-Space>"] = "cycle_win",
              ["<C-,>"] = "toggle_input",
              ["<Left>"] = "preview_scroll_left",
              ["<Right>"] = "preview_scroll_right",
              ["<C-Left>"] = "preview_scroll_left",
              ["<C-Right>"] = "preview_scroll_right",
              ["<localleader>o"] = "reveal_file",
              ["<leader>fO"] = "reveal_file",
            },
          },
          preview = {
            wo = {
              signcolumn = "no",
              number = false,
              winbar = "", -- disable dropbar.nvim for Snacks.picker.buffers()
            },
            -- b = { snacks_indent = false },
            keys = {
              ["<Esc>"] = {
                "<Esc>",
                function(self)
                  if not U.keymap.clear_ui_esc({ close = false }) then
                    self:execute("toggle_focus")
                  end
                end,
                desc = "Clear UI or Focus Input",
              },
              ["<C-Space>"] = { "cycle_win", mode = { "n", "i" } },
            },
          },
        },
      },
    },
  },

  -- TODO: find a way to use `U.path.shorten` before truncation
  {
    "folke/snacks.nvim",
    optional = true,
    opts = function(_, opts)
      -- HACK: add right padding
      local orig_truncpath = Snacks.picker.util.truncpath
      Snacks.picker.util.truncpath = function(path, len, _opts)
        return orig_truncpath(path, len - 1, _opts)
      end

      return U.extend_tbl(opts, {
        picker = {
          formatters = {
            file = {
              truncate = "left",
            },
          },
        },
      } --[[@as snacks.Config]])
    end,
  },
  {
    "folke/snacks.nvim",
    optional = true,
    opts = function()
      do
        -- using `opts.picker.formatters.file.truncate`
        -- NOTE: not working after https://github.com/folke/snacks.nvim/commit/d5b6d30
        return
      end

      ---@param dir string
      ---@param len number
      ---@return string
      local function trunc_dir(dir, len)
        if len <= 1 then
          return ""
        end

        dir = U.path.shorten(dir)
        -- ref: https://github.com/folke/snacks.nvim/blob/e039139291f85eebf3eeb41cc5ad9dc4265cafa4/lua/snacks/picker/util/init.lua#L36-L61
        if vim.api.nvim_strwidth(dir) <= len then
          return dir
        end

        local parts = vim.split(dir:gsub("/$", ""), "/")
        -- single part, e.g. "foobar/" ("foobar/baz") -> "foob…/" ("foob…/baz")
        if #parts < 2 then
          return U.truncate(dir, len - 1) .. "/"
        end

        -- -- TODO: https://github.com/folke/snacks.nvim/blob/e039139291f85eebf3eeb41cc5ad9dc4265cafa4/lua/snacks/picker/util/init.lua#L46-L61
        -- local ret = table.remove(parts)
        -- local first = table.remove(parts, 1)
        -- if (first == "~" or first == "") and #parts > 0 then
        --   first = first .. "/" .. table.remove(parts, 1)
        -- end
        return U.truncate(dir, len, -1)
      end

      -- HACK: shorten & truncate dir | https://github.com/folke/snacks.nvim/blob/2568f18c4de0f43b15b0244cd734dcb5af93e53f/lua/snacks/picker/format.lua#L51
      Snacks.picker.util.truncpath = function(path)
        return path
      end
      local orig_filename = Snacks.picker.format._filename
      Snacks.picker.format._filename = function(ctx)
        local ret = orig_filename(ctx)
        local picker = ctx.picker
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
            text[1] = trunc_dir(text[1], dir_trunc_len)
            break
          end
        end
        return ret
      end
    end,
  },

  {
    "folke/snacks.nvim",
    keys = function(_, keys)
      if LazyVim.pick.picker.name == "snacks" then
        table.insert(keys, {
          "<leader><space>",
          function()
            ---@diagnostic disable-next-line: undefined-field
            Snacks.picker.files_with_ignored({ cwd = LazyVim.root() })
          end,
          desc = "Find Files (Root Dir)",
        })
      end
      return keys
    end,
    ---@type snacks.Config
    opts = {
      picker = {
        sources = {
          -- ignored by git, but we still want to search them
          -- ref: https://github.com/folke/snacks.nvim/blob/bc902f7032df305df7dc48104cfa4e37967b3bdf/lua/snacks/picker/source/files.lua#L153-L179
          ---@class snacks.picker.ignored.Config: snacks.picker.proc.Config
          ---@field follow? boolean follow symlinks
          ---@field ft? string|string[] file extension(s)
          ---@field patterns? string[] ignored patterns to search
          ignored = {
            ---@param opts snacks.picker.ignored.Config
            ---@type snacks.picker.finder
            finder = function(opts, ctx)
              local cmd, args = require("snacks.picker.source.files").get_cmd("rg")
              local patterns = opts.patterns or {}
              if not (cmd and args and #patterns > 0) then
                return function() end
              end
              local cwd = vim.fs.normalize(opts and opts.cwd or vim.uv.cwd() or ".")
              table.insert(args, "--no-ignore-global") -- or `--no-ignore-vcs`, it depends on patterns like "**/.claude/**", `--no-ignore-global` has better performance
              for _, p in ipairs(patterns) do
                vim.list_extend(args, { "-g", p })
              end
              -- follow
              if opts.follow then
                args[#args + 1] = "-L"
              end
              if opts.debug.files then
                Snacks.notify(cmd .. " " .. table.concat(args or {}, " "))
              end
              return require("snacks.picker.source.proc").proc(
                ctx:opts({
                  cmd = cmd,
                  args = args,
                  notify = false, -- if no match could be found, then the exit status is 1, see `man rg`
                  ---@param item snacks.picker.finder.Item
                  ---@param _ctx snacks.picker.finder.ctx
                  transform = function(item, _ctx)
                    item.cwd = cwd
                    item.file = item.text
                    -- see: https://github.com/folke/snacks.nvim/blob/f32002607a5a81a1d25eda27b954fc6ba8e9fd1b/lua/snacks/picker/format.lua#L70-L87
                    -- item.ignored = true -- SnacksPickerPathIgnored
                    item.filename_hl = "SnacksPickerDimmed" -- SnacksPickerIconArray

                    -- extensions
                    -- respect `picker.opts.ft` in favor of `filter_extension` action
                    -- https://github.com/folke/snacks.nvim/blob/bc902f7032df305df7dc48104cfa4e37967b3bdf/lua/snacks/picker/source/files.lua#L75-L90
                    local _opts = _ctx.picker.opts --[[@as snacks.picker.files.Config]]
                    if _opts.ft and vim.fn.fnamemodify(item.file, ":e") ~= _opts.ft then
                      return false
                    end

                    -- file glob
                    -- for `supports_live = true`
                    -- https://github.com/folke/snacks.nvim/blob/bc902f7032df305df7dc48104cfa4e37967b3bdf/lua/snacks/picker/source/files.lua#L112-L128
                    if
                      _ctx.filter.search ~= ""
                      -- alternatives:
                      -- - https://github.com/folke/snacks.nvim/blob/080320bb820ffdb6103f993da076b100ea68333c/lua/snacks/picker/core/preview.lua#L337-L353
                      -- - vim.regex(_ctx.filter.search):match_str(item.file)
                      -- - vim.glob.to_lpeg(_ctx.filter.search):match(item.file)
                      and not item.file:find(_ctx.filter.search)
                    then
                      return false
                    end
                  end,
                }),
                ctx
              )
            end,
            patterns = {
              ".nvim.lua",
              ".lazy.lua",
              ".env",
              ".env.*",
              "AGENTS.md",
              "CLAUDE.md",
              "CLAUDE.local.md",
              ".mcp.json",
              "**/.claude/**",
            },
            -- ref: https://github.com/folke/snacks.nvim/blob/3d695ab7d062d40c980ca5fd9fe6e593c8f35b12/lua/snacks/picker/config/sources.lua#L200-L208
            format = "file",
            show_empty = true,
            follow = true,
            supports_live = true,
          },
          -- ref: https://github.com/folke/snacks.nvim/blob/3d695ab7d062d40c980ca5fd9fe6e593c8f35b12/lua/snacks/picker/config/sources.lua#L788-L797
          files_with_ignored = {
            multi = { "files", "ignored" },
            format = "file",
            transform = "unique_file",
            supports_live = true,
          },
        },
      },
    },
    specs = {
      {
        "folke/snacks.nvim",
        keys = function(_, keys)
          if LazyVim.pick.picker.name == "snacks" then
            -- stylua: ignore
            vim.list_extend(keys, {
              ---@diagnostic disable-next-line: undefined-field
              { "<leader>ff", function() Snacks.picker.smart_with_ignored({ cwd = LazyVim.root() }) end, desc = "Smart (Root Dir)" },
              ---@diagnostic disable-next-line: undefined-field
              { "<leader>fF", function() Snacks.picker.smart_with_ignored() end, desc = "Smart (cwd)" },
            })
          end
          return keys
        end,
        opts = function(_, opts)
          local sources = require("snacks.picker.config.sources")

          local smart_with_ignored = vim.deepcopy(sources.smart)
          if smart_with_ignored.multi then
            table.insert(smart_with_ignored.multi, "ignored")
          end

          return U.extend_tbl(opts, {
            picker = {
              sources = {
                smart_with_ignored = smart_with_ignored,
              },
            },
          } --[[@as snacks.Config]])
        end,
      },
    },
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
              return path and U.path.shorten(path, { relative = false }) or ""
            end,
          },
          lualine_z = {
            function()
              local picker = Snacks.picker.get()[1]
              local source = picker and picker.opts.source
              return ({ files_with_ignored = "files", smart_with_ignored = "smart" })[source] or source or "custom"
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
      { "<leader>sp", H.pick_search_lazy_specs, desc = "Lazy Plugin Spec" },
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
      unpack(H.mappings),
    },
    opts = {
      defaults = {
        prompt_prefix = "", -- in favor of `p` in normal mode on startup
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
    lazy = true,
    optional = true,
    opts = function(_, opts)
      -- we have snacks input
      opts = U.extend_tbl(opts, { input = { enabled = false } })
      -- fzf/snacks as picker and dressing.nvim as dependency of other plugins
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
          require("telescope").extensions.smart_open.smart_open()
        end,
        desc = "Smart Open",
      },
      {
        "<leader>fF",
        function()
          require("telescope").extensions.smart_open.smart_open({ cwd_only = true })
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
