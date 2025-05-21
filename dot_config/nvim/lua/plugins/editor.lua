return {
  {
    "MagicDuck/grug-far.nvim",
    optional = true,
    cmd = "GrugFarWithin",
    keys = {
      {
        "<leader>sr",
        function()
          local ext = vim.bo.buftype == "" and vim.fn.expand("%:e")
          require("grug-far").open({
            transient = true,
            prefills = {
              filesFilter = ext and ext ~= "" and "*." .. ext or nil,
              paths = LazyVim.root(),
            },
          })
        end,
        mode = { "n", "v" },
        desc = "Search and Replace",
      },
      {
        "<leader>sF",
        mode = { "n", "v" },
        function()
          require("grug-far").open({
            transient = true,
            prefills = {
              paths = vim.fn.expand("%"),
              flags = "--fixed-strings",
              search = vim.fn.expand("<cword>"),
            },
            minSearchChars = 1,
          })
        end,
        desc = "Search and Replace in Current File",
      },
      {
        "<leader>ss",
        mode = "x",
        function()
          if vim.fn.mode() == vim.keycode("<C-v>") then
            vim.api.nvim_feedkeys(vim.keycode([[:GrugFarWithin<CR>]]), "n", false)
          else
            -- not working for <C-v>
            require("grug-far").open({
              visualSelectionUsage = "operate-within-range",
              minSearchChars = 1,
            })
          end
        end,
        desc = "Search and Replace Within Range",
      },
    },
    opts = function(_, opts)
      vim.api.nvim_create_autocmd("FileType", {
        group = vim.api.nvim_create_augroup("grug_far_keymap", { clear = true }),
        pattern = "grug-far",
        callback = function(ev)
          vim.keymap.set("n", "<localleader>f", function()
            local state = unpack(require("grug-far").get_instance(0):toggle_flags({ "--fixed-strings" }))
            LazyVim.info(("Toggled `--fixed-strings`: **%s**"):format(state and "ON" or "OFF"), { title = "Grug Far" })
          end, { buffer = ev.buf, desc = "Toggle --fixed-strings" })

          vim.keymap.set("n", "<left>", function()
            require("grug-far").get_instance(0):goto_first_input()
          end, { buffer = ev.buf, desc = "Jump Back to Search Input (Grug Far)" })

          vim.keymap.set(
            "n",
            "<C-S>",
            vim.tbl_get(opts, "keymaps", "syncLocations", "n") or "<localleader>s",
            { buffer = ev.buf, remap = true, desc = "Sync All" }
          )
        end,
      })

      opts.keymaps = vim.tbl_deep_extend("force", opts.keymaps or {}, {
        refresh = { n = "<localleader>R" },
      })
    end,
  },

  -- better `:substitute`
  {
    "chrisgrieser/nvim-rip-substitute",
    shell_command_editor = true,
    cmd = "RipSubstitute",
    keys = {
      {
        "<leader>sf",
        mode = { "n", "x" },
        function()
          -- popup overlaps when `opts.popupWin.position == "top"`
          Snacks.notifier.hide()
          require("rip-substitute").sub()
          if vim.api.nvim_get_current_line() ~= "" then
            vim.cmd("stopinsert")
          end
        end,
        desc = "Rip Substitute",
      },
    },
    opts = {
      popupWin = {
        position = "top",
        disableCompletions = false,
      },
      keymaps = {
        insertModeConfirm = "<C-s>",
        toggleFixedStrings = "<localleader>f",
        toggleIgnoreCase = "<localleader>c",
      },
      regexOptions = {
        startWithFixedStringsOn = true,
        -- startWithIgnoreCase = true,
      },
      prefill = {
        startInReplaceLineIfPrefill = true,
        alsoPrefillReplaceLine = true,
      },
    },
    config = function(_, opts)
      require("rip-substitute").setup(opts)

      local abort_key = vim.keycode(vim.tbl_get(opts, "keymaps", "abort") or "q")
      if abort_key ~= vim.keycode("<esc>") then
        vim.api.nvim_create_autocmd("FileType", {
          pattern = "rip-substitute",
          callback = function(event)
            vim.keymap.set("n", "<esc>", function()
              U.keymap.clear_ui_esc({
                close = function()
                  vim.api.nvim_feedkeys(abort_key, "m", false)
                end,
              })
            end, {
              buffer = event.buf,
              silent = true,
              desc = "Clear UI or Abort (Rip Substitute)",
            })
          end,
        })
      end
    end,
    specs = {
      {
        "folke/noice.nvim",
        optional = true,
        opts = function(_, opts)
          opts.routes = vim.list_extend(opts.routes or {}, {
            {
              filter = {
                event = { "msg_show", "notify" },
                cond = function()
                  return vim.bo.filetype == "rip-substitute"
                end,
              },
              view = "mini",
            },
          })
        end,
      },
    },
  },

  {
    "folke/flash.nvim",
    optional = true,
    keys = function(_, keys)
      -- https://github.com/JoseConseco/nvim_config/blob/23dbf5f8b9779d792643ab5274ebe8dabe79c0c0/lua/plugins.lua#L1049
      ---@param skip_first_match? boolean default false
      local function treesitter(skip_first_match)
        ---@type Flash.State.Config|{}
        local opts = { label = { rainbow = { enabled = true } } }
        if skip_first_match then
          ---@param matches Flash.Match.TS[]
          opts.filter = function(matches)
            -- before removing first match, match[n+1] should use previous match[n] label
            for i = #matches, 2, -1 do
              matches[i].label = matches[i - 1].label
            end
            -- remove first match, as it is same as word under cursor (not always) thus redundant with word motion
            table.remove(matches, 1)
            return matches
          end
        end
        require("flash").treesitter(opts)
      end

      -- https://github.com/chrisgrieser/.config/blob/88eb71f88528f1b5a20b66fd3dfc1f7bd42b408a/nvim/lua/config/keybindings.lua#L150
      vim.keymap.set("n", "guu", "guu") -- prevent `omap u` from overwriting `guu`
      return vim.list_extend(keys, {
        { "u", mode = { "o", "x" }, treesitter, desc = "Flash Treesitter" }, -- unit textobject, conflict with `guu`
        -- { "S", mode = { "n", "o", "x" }, treesitter, desc = "Flash Treesitter" }, -- conflict with mini.operators, use `vu` instead
        { "r", mode = "o", false },
        { "R", mode = { "o", "x" }, false },
        {
          "<space>",
          mode = "o",
          function()
            require("flash").remote()
          end,
          desc = "Remote Flash",
        },
        {
          "<tab>",
          mode = { "o", "x" },
          function()
            require("flash").treesitter_search({ label = { rainbow = { enabled = true } } })
          end,
          desc = "Treesitter Search",
        },
      })
    end,
  },

  {
    "folke/which-key.nvim",
    keys = {
      -- HACK: fix the popup not showing on `<localleader>`
      -- https://github.com/folke/which-key.nvim/issues/172#issuecomment-2002609310
      {
        "<localleader>?",
        function()
          require("which-key").show({ global = false })
        end,
        desc = "Buffer Keymaps (which-key)",
      },
    },
    opts = {
      keys = {
        scroll_down = "<c-f>",
        scroll_up = "<c-b>",
      },
    },
  },

  {
    "folke/trouble.nvim",
    optional = true,
    -- opts = { focus = true },
    -- stylua: ignore
    keys = {
      -- add `focus=true`
      { "<leader>xx", "<cmd>Trouble diagnostics toggle focus=true<cr>", desc = "Diagnostics (Trouble)" },
      { "<leader>xX", "<cmd>Trouble diagnostics toggle focus=true filter.buf=0<cr>", desc = "Buffer Diagnostics (Trouble)" },
      { "<leader>cs", "<cmd>Trouble symbols toggle focus=true<cr>", desc = "Symbols (Trouble)" },
      { "<leader>cS", "<cmd>Trouble lsp toggle focus=true<cr>", desc = "LSP references/definitions/... (Trouble)" },
      { "<leader>xL", "<cmd>Trouble loclist toggle focus=true<cr>", desc = "Location List (Trouble)" }, -- e.g. `:lgrep {pattern} {file}` like `:lgrep TODO %`
      { "<leader>xQ", "<cmd>Trouble qflist toggle focus=true<cr>", desc = "Quickfix List (Trouble)" },
    },
  },
  {
    "folke/todo-comments.nvim",
    optional = true,
    -- stylua: ignore
    keys = {
      -- add `focus=true`
      { "<leader>xt", "<cmd>Trouble todo toggle focus=true<cr>", desc = "Todo (Trouble)" },
      { "<leader>xT", "<cmd>Trouble todo toggle focus=true filter = {tag = {TODO,FIX,FIXME}}<cr>", desc = "Todo/Fix/Fixme (Trouble)" },
    },
  },

  {
    "ThePrimeagen/refactoring.nvim",
    optional = true,
    -- stylua: ignore
    keys = {
      {"<leader>rs", false, mode = "v"},
      {"<leader>rr", function() require('refactoring').select_refactor() end, mode = {"n", "v"}, desc = "Refactor"},
      {"<leader>rx", function() return require("refactoring").refactor("Extract Variable") end, mode = {"n", "v"}, desc = "Extract Variable", expr = true},
      {"<leader>ri", function() return require("refactoring").refactor("Inline Variable") end, mode = {"n", "v"}, desc = "Inline Variable", expr = true},
      {"<leader>rI", function() return require("refactoring").refactor("Inline Function") end, mode = {"n", "v"}, desc = "Inline Function", expr = true},
      {"<leader>rf", function() return require("refactoring").refactor("Extract Function") end, mode = {"n", "v"}, desc = "Extract Function", expr = true},
      {"<leader>rF", function() return require("refactoring").refactor("Extract Function To File") end, mode = {"n", "v"}, desc = "Extract Function To File", expr = true},
      {"<leader>rb", function() return require("refactoring").refactor("Extract Block") end, mode = {"n", "v"}, desc = "Extract Block", expr = true},
      {"<leader>rB", function() return require("refactoring").refactor("Extract Block To File") end, mode = {"n", "v"}, desc = "Extract Block To File", expr = true},
      {"<leader>rP", false},
      {"<leader>rp", false},
      {"<leader>rc", false},
      {"<leader>rp", false, mode = "v"},
      {"<leader>rd", "", desc = "+debug", mode = {"n", "v"}},
      {"<leader>rdd", function() require("refactoring").debug.print_var({}) end, desc = "Debug Print Variable", mode = {"n", "v"}},
      {"<leader>rd<space>", function() require("refactoring").debug.cleanup({}) end, desc = "Debug Cleanup"},
      {"<leader>rdp", function() require("refactoring").debug.printf({below = true}) end, desc = "Debug Print Below"},
      {"<leader>rdP", function() require("refactoring").debug.printf({below = false}) end, desc = "Debug Print Above"},
    },
  },

  {
    "ThePrimeagen/harpoon",
    optional = true,
    dependencies = { "nvim-telescope/telescope.nvim", optional = true },
    keys = function(_, keys)
      if LazyVim.has("telescope.nvim") then
        table.insert(keys, { "<leader>fh", "<Cmd>Telescope harpoon marks<CR>", desc = "Harpoon Files" })
      end
      for i = 1, 5 do
        table.insert(keys, { "<leader>" .. i, false })
      end
      -- stylua: ignore
      vim.list_extend(keys, {
        { "<C-n>", function() require("harpoon"):list():next({ ui_nav_wrap = true }) end, desc = "Next Harpoon File" },
        { "<C-p>", function() require("harpoon"):list():prev({ ui_nav_wrap = true }) end, desc = "Prev Harpoon File" },
      })
    end,
    opts = function()
      local harpoon = require("harpoon")
      local harpoon_extensions = require("harpoon.extensions")
      harpoon:extend(harpoon_extensions.builtins.highlight_current_file())
    end,
    specs = {
      {
        "catppuccin",
        optional = true,
        opts = { integrations = { harpoon = true } },
      },
    },
  },

  {
    "RRethy/vim-illuminate",
    optional = true,
    opts = function(_, opts)
      -- opts.under_cursor = false
      opts.modes_allowlist = {
        "n",
        "nt",
        -- "no", -- vim.hl.on_yank()
      }
      opts.filetypes_denylist =
        vim.list_extend(opts.filetypes_denylist or vim.deepcopy(require("illuminate.config").filetypes_denylist()), {
          "DiffviewFiles",
          "DiffviewFileHistory",
          "NeogitStatus",
          "NeogitPopup",
          -- "lazy",
          -- "mason",
          -- "harpoon",
          -- "qf",
          -- "netrw",
          -- "neo-tree",
          -- "oil",
          -- "minifiles",
          -- "trouble",
          -- "notify",
          -- "TelescopePrompt",
          -- "snacks_picker_input",
        })
    end,
  },

  {
    "y3owk1n/undo-glow.nvim",
    pager = true,
    shell_command_editor = true,
    dependencies = {
      {
        "gbprod/yanky.nvim",
        optional = true,
        keys = { { "p", false }, { "P", false } },
        opts = { highlight = { on_yank = false, on_put = false } },
      },
    },
    event = { "TextYankPost", "CmdLineLeave" },
    keys = function(_, keys)
      -- stylua: ignore
      vim.list_extend(keys, {
        {
          "u",
          function()
            require("undo-glow").undo()
            if _G.MiniSnippets then
              MiniSnippets.session.stop()
            end
          end,
          desc = "Undo (undo-glow)",
        },
        { "U", function() require("undo-glow").redo() end, desc = "Redo (undo-glow)" },
        {
          "gc",
          function()
            local pos = vim.fn.getpos(".")
            vim.schedule(function()
              vim.fn.setpos(".", pos)
            end)
            return require("undo-glow").comment({
              animation = {
                animation_type = "desaturate",
              },
            })
          end,
          mode = { "n", "x" },
          desc = "Toggle comment (undo-glow)",
          expr = true,
        },
        {
          "gcc",
          function()
            return require("undo-glow").comment_line({
              animation = {
                animation_type = "desaturate",
              },
            })
          end,
          desc = "Toggle comment line (undo-glow)",
          expr = true,
        },
      })

      if LazyVim.has("yanky.nvim") then
        vim.list_extend(keys, {
          {
            "p",
            function()
              -- copied from: https://github.com/y3owk1n/undo-glow.nvim/blob/7a224dead8cc94fee57d753b188413910dd5b98c/lua/undo-glow/init.lua#L138
              local opts = require("undo-glow.utils").merge_command_opts("UgPaste")
              require("undo-glow").highlight_changes(opts)
              return "<Plug>(YankyPutAfter)"
            end,
            desc = "Put Text After Cursor (undo-glow)",
            expr = true,
          },
          {
            "P",
            function()
              -- copied from: https://github.com/y3owk1n/undo-glow.nvim/blob/7a224dead8cc94fee57d753b188413910dd5b98c/lua/undo-glow/init.lua#L145
              local opts = require("undo-glow.utils").merge_command_opts("UgPaste")
              require("undo-glow").highlight_changes(opts)
              return "<Plug>(YankyPutBefore)"
            end,
            desc = "Put Text Before Cursor (undo-glow)",
            expr = true,
          },
        })
      else
        -- stylua: ignore
        vim.list_extend(keys, {
          { "p", function() require("undo-glow").paste_below() end, desc = "Put Text After Cursor (undo-glow)" },
          { "P", function() require("undo-glow").paste_above() end, desc = "Put Text Before Cursor (undo-glow)" },
        })
      end
    end,
    opts = function()
      Snacks.util.set_hl({
        UgUndo = "Substitute",
        UgRedo = "FlashLabel",
        UgYank = "IncSearch",
        UgPaste = "Search",
        UgSearch = { fg = "#000000", bg = Snacks.util.color("Identifier"), bold = true }, -- TodoBgPERF
        UgComment = "LspReferenceText",
        UgCursor = "Visual",
      }, { default = true })

      ---@module 'undo-glow'
      ---@type UndoGlow.Config
      return {
        priority = 2048 * 3,
        animation = {
          enabled = true,
          duration = 150,
          animation_type = "zoom",
          window_scoped = true,
        },
      }
    end,
    init = function()
      vim.api.nvim_create_autocmd("User", {
        pattern = "LazyVimAutocmdsDefaults",
        callback = function()
          vim.api.nvim_del_augroup_by_name("lazyvim_highlight_yank")
        end,
      })
      vim.api.nvim_create_autocmd("TextYankPost", {
        group = vim.api.nvim_create_augroup("undo_glow_highlight_yank", { clear = true }),
        callback = function()
          -- copied from: https://github.com/neovim/neovim/blob/c3337e357a838aadf0ac40dd5bbc4dd0d1909b32/runtime/lua/vim/hl.lua#L163-L175
          local event = vim.v.event
          local on_macro = false
          local on_visual = true
          if not on_macro and vim.fn.reg_executing() ~= "" then
            return
          end
          if event.operator ~= "y" or event.regtype == "" then
            return
          end
          if not on_visual and event.visual then
            return
          end
          vim.schedule(require("undo-glow").yank)
        end,
      })

      vim.api.nvim_create_autocmd("CmdLineLeave", {
        group = vim.api.nvim_create_augroup("undo_glow_highlight_search", { clear = true }),
        pattern = { "/", "?" },
        callback = function()
          require("undo-glow").search_cmd({
            animation = {
              duration = 200,
              animation_type = "fade",
            },
          })
        end,
      })

      LazyVim.on_very_lazy(function()
        vim.api.nvim_create_autocmd({ "WinEnter", "FocusGained" }, {
          group = vim.api.nvim_create_augroup("undo_glow_highlight_win_enter", { clear = true }),
          callback = U.debounce_wrap(20, function(ev)
            -- copied from: https://github.com/y3owk1n/undo-glow.nvim/blob/41010d31181d75123c87916a25e4796e0e7c20f8/lua/undo-glow/commands.lua#L212-L268
            local buf = ev.buf
            local win = vim.api.nvim_get_current_win()
            if
              not vim.api.nvim_buf_is_valid(buf)
              or not vim.api.nvim_buf_is_loaded(buf)
              or vim.wo[win].previewwindow
              or vim.api.nvim_win_get_config(win).relative ~= ""
              or vim.bo[buf].buftype ~= ""
            then
              return
            end

            local opts = require("undo-glow.utils").merge_command_opts("UgCursor", {
              animation = not U.has_user_extra("ui.nvchad-ui") and {
                duration = 500,
                animation_type = "slide",
              } or nil,
            })
            local lnum = vim.api.nvim_win_get_cursor(0)[1]
            local line = vim.api.nvim_get_current_line()
            require("undo-glow").highlight_region(vim.tbl_extend("force", opts, {
              s_row = lnum - 1,
              s_col = 0,
              e_row = lnum - 1,
              e_col = #line,
              force_edge = opts.force_edge ~= false,
            }))
          end),
        })
      end)
    end,
  },

  {
    "kevinhwang91/nvim-hlslens",
    pager = true,
    shell_command_editor = true,
    vscode = true,
    dependencies = {
      -- https://github.com/kevinhwang91/nvim-hlslens/issues/64#issuecomment-1606196924
      -- alternative: https://github.com/rapan931/lasterisk.nvim
      { "haya14busa/vim-asterisk", pager = true, shell_command_editor = true, vscode = true },
      { "petertriho/nvim-scrollbar", optional = true },
    },
    event = "CmdlineEnter",
    -- stylua: ignore
    keys = {
      { "n", [[<Cmd>execute('normal! ' . v:count1 . 'nzv') | lua require('hlslens').start()<CR>]] }, -- see: #65
      { "N", [[<Cmd>execute('normal! ' . v:count1 . 'Nzv') | lua require('hlslens').start()<CR>]] },
      -- { "*", [[*zv<Cmd>lua require('hlslens').start()<CR>]] },
      -- { "#", [[#zv<Cmd>lua require('hlslens').start()<CR>]] },
      -- { "g*", [[g*zv<Cmd>lua require('hlslens').start()<CR>]] },
      -- { "g#", [[g#zv<Cmd>lua require('hlslens').start()<CR>]] },
      { "*", mode = { "n", "x" }, [[<Plug>(asterisk-*)zv<Cmd>lua require('hlslens').start()<CR>]] },
      { "#", mode = { "n", "x" }, [[<Plug>(asterisk-#)zv<Cmd>lua require('hlslens').start()<CR>]] },
      { "g*", mode = { "n", "x" }, [[<Plug>(asterisk-g*)zv<Cmd>lua require('hlslens').start()<CR>]] },
      { "g#", mode = { "n", "x" }, [[<Plug>(asterisk-g#)zv<Cmd>lua require('hlslens').start()<CR>]] },
      { "gw", mode = { "n", "x" }, [[<Plug>(asterisk-z*)<Cmd>lua require('hlslens').start()<CR>]], desc = "Search word under cursor" },
    },
    opts = {
      -- enable_incsearch = false,
      calm_down = true,
      nearest_only = true,
      -- https://github.com/fjchen7/dotfiles/blob/a45b0a2778c18d82d5b3cba88de05e9351bee713/config/nvim/lua/plugins/ui/hlslens.lua#L16
      override_lens = function(render, posList, nearest, idx, relIdx)
        -- -- only show lens of the nearest matched, redundant with `nearest_only`
        -- if not nearest then
        --   return
        -- end

        -- -- only show lens when the cursor at the start of position range of the nearest matched
        -- if relIdx ~= 0 then
        --   return
        -- end

        local indicator = vim.v.searchforward == 0 and "▲" or ""
        local lnum, col = unpack(posList[idx])
        local cnt = #posList
        local text
        -- -- noice style
        -- if nearest then
        --   text = ("%s%s    [%d/%d]"):format(vim.v.searchforward == 0 and "?" or "/", vim.fn.getreg("/"), idx, cnt)
        -- else
        --   text = ("[%d/%d]"):format(idx, cnt)
        -- end
        if nearest and indicator ~= "" then
          text = ("[%s %d/%d]"):format(indicator, idx, cnt)
        else
          text = ("[%d/%d]"):format(idx, cnt)
        end
        local hl = nearest and "HlSearchLensNear" or "HlSearchLens"
        local chunks = { { " " }, { text, hl } }
        render.setVirt(0, lnum - 1, col - 1, chunks, nearest)
      end,
    },
    config = function(_, opts)
      if LazyVim.has("nvim-scrollbar") then
        require("scrollbar.handlers.search").setup(opts)
      else
        require("hlslens").setup(opts)
      end

      local Render = require("hlslens.render")

      -- HACK: `calm_down` lens only, keep the hlsearch
      -- copied from: https://github.com/kevinhwang91/nvim-hlslens/blob/07afd4dd14405ad14b142a501a3abea6ae44b21b/lua/hlslens/render/init.lua#L53
      function Render:doNohAndStop(defer)
        local function f()
          -- vim.cmd("noh") -- commented out this line
          self:stop()
        end

        if defer then
          vim.schedule(f)
        else
          f()
        end
      end
    end,
    specs = {
      {
        "folke/noice.nvim",
        optional = true,
        opts = function(_, opts)
          opts.messages = opts.messages or {}
          opts.messages.view_search = false -- using nvim-hlslens

          -- opts.debug = true
          opts.routes = opts.routes or {}
          table.insert(opts.routes, {
            filter = {
              event = "msg_show",
              any = {
                -- { find = "^[/?].*" }, -- search up/down when pattern not found
                -- { find = "^E486: Pattern not found:" }, -- search pattern not found
                { find = "^%s*W? %[%d+/%d+%]$" }, -- search count by */#/g*/g# in both normal and visual mode
                { find = [[^\<.+\>$]] }, -- <Plug>(asterisk-z*)
                { find = [[^\V.+]] }, -- <Plug>(asterisk-z*)
              },
            },
            view = "mini",
          })
        end,
      },
    },
  },

  {
    "wurli/visimatch.nvim",
    pager = true,
    shell_command_editor = true,
    event = "ModeChanged *:[vV]",
    opts = {
      chars_lower_limit = 2,
      buffers = function(buf)
        return vim.bo[buf].buflisted and vim.bo[buf].buftype == ""
          or vim.bo[buf].buftype == "terminal"
          or buf == vim.api.nvim_win_get_buf(0)
      end,
      -- case_insensitive = true,
    },
  },

  {
    "chrisgrieser/nvim-origami",
    event = "VeryLazy",
    dependencies = {
      "kevinhwang91/nvim-ufo",
      optional = true,
      keys = { { "<leader>iF", false } },
    },
    init = function()
      if LazyVim.has("nvim-ufo") then
        return
      end

      -- -- copied from: https://github.com/chrisgrieser/.config/blob/832fa40a0648b31780658b59138379851a5231ec/nvim/lua/config/options.lua#L161-L181
      -- vim.o.foldlevel = 99 -- do not auto-fold
      vim.o.foldlevelstart = 99
      -- vim.o.foldtext = "" -- empty string keeps text (overwritten by nvim-origami)

      -- -- LSP -> Treesitter
      -- vim.o.foldmethod = "expr"
      -- vim.o.foldexpr = "v:lua.vim.treesitter.foldexpr()"
      vim.api.nvim_create_autocmd("LspAttach", {
        desc = "User: Prefer LSP folding if client supports it",
        callback = function(args)
          local client = vim.lsp.get_client_by_id(args.data.client_id)
          if client and client:supports_method("textDocument/foldingRange") then
            local win = vim.api.nvim_get_current_win()
            vim.wo[win][0].foldexpr = "v:lua.vim.lsp.foldexpr()"
          end
        end,
      })
    end,
    keys = function()
      -- https://github.com/folke/snacks.nvim/blob/4c52b7f25da0ce6b2b830ce060dbd162706acf33/lua/snacks/scroll.lua#L275-L282
      local repeat_delay = 100
      local last = 0
      return {
        {
          "h",
          function()
            local count1 = vim.v.count1
            local now = vim.uv.hrtime()
            local repeat_delta = (now - last) / 1e6
            last = now
            if repeat_delta <= repeat_delay then
              vim.cmd("normal! " .. count1 .. "h")
            else
              require("origami").h()
            end
          end,
          desc = "Left (Origami)",
        },
        {
          "l",
          function()
            require("origami").l()
          end,
          desc = "Right (Origami)",
        },
        {
          "<leader>iF",
          function()
            if LazyVim.has("nvim-ufo") then
              pcall(vim.cmd.UfoInspect)
            end
            require("origami").inspectLspFolds("special")
          end,
          desc = "Fold",
        },
      }
    end,
    opts = function()
      local has_ufo = LazyVim.has("nvim-ufo")
      return {
        foldKeymaps = {
          setup = false,
          hOnlyOpensOnFirstColumn = true,
        },
        useLspFoldsWithTreesitterFallback = false,
        autoFold = {
          enabled = not has_ufo,
          kinds = {
            "imports",
            -- "comment",
          }, ---@type lsp.FoldingRangeKind[]
        },
        foldtextWithLineCount = {
          enabled = not has_ufo,
          template = "  󰘖 %s",
        },
        keepFoldsAcrossSessions = false, -- has_ufo
      }
    end,
  },

  -- alternative: https://github.com/echasnovski/mini.keymap
  {
    "max397574/better-escape.nvim",
    event = { "InsertEnter", "CmdlineEnter" },
    opts = {
      default_mappings = false, -- j/k navigation in lazygit/fzf-lua
      mappings = {
        i = {
          j = { j = "<Esc>", k = "<Esc>" },
          k = { j = "<Esc>" },
        },
        c = {
          j = { j = "<Esc>", k = "<Esc>" },
          k = { j = "<Esc>" },
        },
      },
    },
  },

  -- alternatives:
  -- * https://github.com/xzbdmw/nvimconfig/blob/0be9805dac4661803e17265b435060956daee757/lua/theme/dark.lua#L23
  -- * https://github.com/pogyomo/submode.nvim
  -- * https://github.com/anuvyklack/hydra.nvim
  -- * https://github.com/echasnovski/mini.nvim/blob/6105b69d79fef0afed5ed576081b1997ef2b4be1/doc/mini-clue.txt#L357
  {
    "debugloop/layers.nvim",
    keys = {
      -- stylua: ignore
      { "M", function() PAGER_MODE:toggle() end, desc = "Pager Mode" },
    },
    ---@type layers.setup_opts
    opts = {
      mode = {
        ---@diagnostic disable-next-line: missing-fields
        window = {
          config = {
            zindex = 500,
            title_pos = "center",
            width = 16,
            height = 3,
          },
        },
      },
    },
    config = function(_, opts)
      require("layers").setup(opts)

      _G.PAGER_MODE = Layers.mode.new(" Pager Mode ")
      PAGER_MODE:auto_show_help()
      local esc_timer
      PAGER_MODE:keymaps({
        n = {
          { "u", "<C-u>", { desc = "Scroll Up" } },
          { "d", "<C-d>", { desc = "Scroll Down", nowait = true } },
          {
            "<esc>",
            function()
              esc_timer = esc_timer or assert(vim.uv.new_timer())
              if esc_timer:is_active() then
                esc_timer:stop()
                PAGER_MODE:deactivate()
              else
                esc_timer:start(200, 0, function() end)
                U.keymap.clear_ui_esc()
              end
            end,
            { desc = " Exit " },
          },
        },
        x = {
          { "u", "<C-u>", { desc = "Scroll Up" } },
          { "d", "<C-d>", { desc = "Scroll Down" } },
        },
      })
      local orig_dd_keymap ---@type table<string,any>
      local orig_minianimate_disable ---@type boolean?
      -- local orig_snacks_scroll ---@type boolean?
      PAGER_MODE:add_hook(function(active)
        if active then
          -- set filetype
          if PAGER_MODE._win ~= nil then
            vim.bo[vim.fn.winbufnr(PAGER_MODE._win)].filetype = "layers_help"
          end
          -- remove `dd` mapping, defined in ../config/keymaps.lua
          -- https://github.com/debugloop/layers.nvim/blob/67666f59a2dbe36a469766be6a4c484ae98c4895/lua/layers/map.lua#L52
          orig_dd_keymap = vim.fn.maparg("dd", "n", false, true) --[[@as table<string,any>]]
          if not vim.tbl_isempty(orig_dd_keymap) then
            vim.keymap.del("n", "dd")
          end
          -- disable scroll animate
          orig_minianimate_disable = vim.g.minianimate_disable
          vim.g.minianimate_disable = true
          -- orig_snacks_scroll = vim.g.snacks_scroll
          -- vim.g.snacks_scroll = false
        else
          if not vim.tbl_isempty(orig_dd_keymap) then
            vim.fn.mapset("n", false, orig_dd_keymap)
          end
          vim.g.minianimate_disable = orig_minianimate_disable
          -- vim.g.snacks_scroll = orig_snacks_scroll
        end
      end)
    end,
  },

  {
    "nacro90/numb.nvim",
    event = "CmdlineEnter",
    opts = {},
  },
}
