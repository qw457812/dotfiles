return {
  {
    "MagicDuck/grug-far.nvim",
    optional = true,
    keys = {
      {
        "<leader>sF",
        mode = { "n", "v" },
        function()
          require("grug-far").open({
            transient = true,
            prefills = {
              paths = vim.fn.expand("%"),
              -- https://vi.stackexchange.com/questions/17465/how-to-search-literally-without-any-regex-pattern
              flags = "--fixed-strings",
              search = vim.fn.expand("<cword>"),
            },
            minSearchChars = 1,
          })
        end,
        desc = "Search and Replace in Current File",
      },
    },
    opts = function(_, opts)
      vim.api.nvim_create_autocmd("FileType", {
        group = vim.api.nvim_create_augroup("grug_far_keymap", { clear = true }),
        pattern = "grug-far",
        callback = function(ev)
          -- https://github.com/MagicDuck/grug-far.nvim#create-a-buffer-local-keybinding-to-toggle---fixed-strings-flag
          vim.keymap.set("n", "<localleader>f", function()
            local state = unpack(require("grug-far").toggle_flags({ "--fixed-strings" }) or {})
            LazyVim.info(("Toggled `--fixed-strings`: **%s**"):format(state and "ON" or "OFF"), { title = "Grug Far" })
          end, { buffer = ev.buf, desc = "Toggle --fixed-strings" })

          vim.keymap.set("n", "<left>", function()
            vim.api.nvim_win_set_cursor(vim.fn.bufwinid(0), { 3, 0 })
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
                  -- simulate `q` keypress to abort
                  vim.api.nvim_feedkeys(abort_key, "m", false)
                end,
                esc = false,
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
  },
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
      return opts
    end,
  },

  -- TODO: choose motion plugin between: flash, leap, hop
  -- https://github.com/doctorfree/nvim-lazyman/blob/bb4091c962e646c5eb00a50eca4a86a2d43bcb7c/lua/ecovim/config/plugins.lua#L373
  -- "remote flash" for leap: https://github.com/rasulomaroff/telepath.nvim
  {
    "folke/flash.nvim",
    optional = true,
    keys = function(_, keys)
      -- https://github.com/JoseConseco/nvim_config/blob/23dbf5f8b9779d792643ab5274ebe8dabe79c0c0/lua/plugins.lua#L1049
      -- https://github.com/mfussenegger/nvim-treehopper
      ---@param skip_first_match? boolean default false
      local function treesitter(skip_first_match)
        ---@type Flash.State.Config
        ---@diagnostic disable-next-line: missing-fields
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
    opts = {
      keys = {
        scroll_down = "<c-f>",
        scroll_up = "<c-b>",
      },
    },
  },

  {
    "lewis6991/gitsigns.nvim",
    optional = true,
    opts = function(_, opts)
      opts.attach_to_untracked = true

      local on_attach = opts.on_attach or function(_) end
      opts.on_attach = function(buffer)
        on_attach(buffer)

        ---@module 'gitsigns'
        local gs = package.loaded.gitsigns

        local function map(mode, l, r, desc)
          vim.keymap.set(mode, l, r, { buffer = buffer, desc = desc })
        end

        -- HACK: redraw to update the signs
        local function redraw()
          vim.defer_fn(function()
            Snacks.util.redraw(vim.api.nvim_get_current_win())
          end, 500)
        end

        -- mini.diff like mappings
        map("n", "gh", function()
          gs.stage_hunk()
          redraw()
        end, "Stage Hunk")
        map("v", "gh", function()
          gs.stage_hunk({ vim.fn.line("."), vim.fn.line("v") })
          redraw()
        end, "Stage Hunk")
        map("o", "gh", "<cmd>Gitsigns select_hunk<CR>", "Hunk Textobj")
        map("n", "gH", gs.reset_hunk, "Reset Hunk")
        map("v", "gH", function()
          gs.reset_hunk({ vim.fn.line("."), vim.fn.line("v") })
        end, "Reset Hunk")
        -- https://github.com/chrisgrieser/.config/blob/9bc8b38e0e9282b6f55d0b6335f98e2bf9510a7c/nvim/lua/plugin-specs/gitsigns.lua#L46
        map("n", "<leader>go", function()
          gs.toggle_deleted()
          gs.toggle_word_diff()
          gs.toggle_linehl()
          redraw()
        end, "Toggle Diff Overlay (GitSigns)")

        map("n", "<leader>ghh", function()
          gs.stage_buffer()
          redraw()
        end, "Stage Buffer")
        map("n", "<leader>ghu", function()
          gs.undo_stage_hunk()
          redraw()
        end, "Undo Stage Hunk")
        map("n", "<leader>gD", function()
          gs.diffthis("~")
          if vim.g.user_close_key then
            map("n", vim.g.user_close_key, function()
              vim.keymap.del("n", vim.g.user_close_key, { buffer = buffer })
              vim.cmd.only()
            end, "Close Diff (Gitsigns)")
          end
        end, "Diff This ~")
        map("n", "<leader>g?", gs.toggle_current_line_blame, "Toggle Blame Line (GitSigns)")
      end
    end,
  },
  {
    "echasnovski/mini.diff",
    optional = true,
    keys = function(_, keys)
      -- HACK: redraw to update the signs
      local function redraw(delay)
        vim.defer_fn(function()
          Snacks.util.redraw(vim.api.nvim_get_current_win())
        end, delay or 500)
      end

      vim.list_extend(keys, {
        -- {
        --   "gh",
        --   function()
        --     redraw() -- not working
        --     return require("mini.diff").operator("apply")
        --   end,
        --   expr = true,
        --   silent = true,
        --   desc = "Apply hunks",
        --   mode = { "n", "x" },
        -- },
        {
          "<leader>go",
          function()
            require("mini.diff").toggle_overlay(0)
            redraw(200)
          end,
          desc = "Toggle mini.diff overlay",
        },
      })
    end,
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
      -- opts.filetypes_denylist =
      --   vim.list_extend(opts.filetypes_denylist or vim.deepcopy(require("illuminate.config").filetypes_denylist()), {
      --     "lazy",
      --     "mason",
      --     "harpoon",
      --     "qf",
      --     "netrw",
      --     "neo-tree",
      --     "oil",
      --     "minifiles",
      --     "trouble",
      --     "notify",
      --     "TelescopePrompt",
      --     "snacks_picker_input",
      --   })
    end,
  },

  -- alternative:
  -- * https://github.com/aileot/emission.nvim
  -- * https://github.com/y3owk1n/undo-glow.nvim
  {
    "tzachar/highlight-undo.nvim",
    enabled = false,
    commit = "795fc36f8bb7e4cf05e31bd7e354b86d27643a9e",
    -- vscode = true,
    keys = { { "u" }, { "U" }, { "<C-r>" } },
    opts = function()
      local hl_undo = require("highlight-undo")

      -- link: Search IncSearch Substitute
      Snacks.util.set_hl({ HighlightUndo = "Substitute", HighlightRedo = "HighlightUndo" }, { default = true })

      local redo_U = vim.deepcopy(hl_undo.config.keymaps.redo)
      redo_U.lhs = "U"

      return {
        keymaps = {
          redo_U = redo_U,
          paste = {
            disabled = true,
          },
          Paste = {
            disabled = true,
          },
        },
      }
    end,
  },
  {
    "y3owk1n/undo-glow.nvim",
    -- stylua: ignore
    keys = {
      { "u", function() require("undo-glow").undo() end },
      { "U", function() require("undo-glow").redo() end },
      { "<C-r>", function() require("undo-glow").redo() end },
    },
    opts = function()
      Snacks.util.set_hl({ UgUndo = "Substitute", UgRedo = "UgUndo" }, { default = true })

      ---@type UndoGlow.Config
      ---@diagnostic disable-next-line: missing-fields
      return {
        duration = 200,
      }
    end,
  },

  {
    "kevinhwang91/nvim-hlslens",
    vscode = true,
    dependencies = {
      -- https://github.com/kevinhwang91/nvim-hlslens/issues/64#issuecomment-1606196924
      -- alternative: https://github.com/rapan931/lasterisk.nvim
      { "haya14busa/vim-asterisk" },
      { "petertriho/nvim-scrollbar", optional = true },
    },
    event = "CmdlineEnter",
    keys = function()
      -- -- https://github.com/kevinhwang91/nvim-hlslens#nvim-ufo
      -- local function nN(char)
      --   local ok, winid = require("hlslens").nNPeekWithUFO(char)
      --   if ok and winid then
      --     vim.keymap.set(
      --       "n",
      --       "<CR>",
      --       "<Tab><CR>",
      --       { buffer = true, remap = true, desc = "Switch to nvim-ufo preview window and fire `trace` action" }
      --     )
      --   end
      -- end

      -- stylua: ignore
      return {
        -- { "n", function() nN("n") end },
        -- { "N", function() nN("N") end },
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
      }
    end,
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
      -- see also `:h noh` and `:h shortmess`
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
            -- opts = { skip = true },
            view = "mini",
          })
          return opts
        end,
      },
    },
  },

  {
    "wurli/visimatch.nvim",
    event = "ModeChanged *:[vV]",
    opts = {
      chars_lower_limit = 2,
      buffers = function(buf)
        return vim.bo[buf].buflisted and vim.bo[buf].buftype == ""
          or vim.bo[buf].buftype == "terminal"
          or buf == vim.api.nvim_win_get_buf(0)
      end,
    },
  },

  {
    "kevinhwang91/nvim-ufo",
    dependencies = {
      "kevinhwang91/promise-async",
      {
        "neovim/nvim-lspconfig",
        opts = {
          capabilities = {
            textDocument = {
              foldingRange = {
                dynamicRegistration = false,
                lineFoldingOnly = true,
              },
            },
          },
        },
      },
    },
    event = "VeryLazy",
    init = function()
      -- vim.o.foldcolumn = "0"
      -- vim.o.foldlevel = 99
      vim.o.foldlevelstart = 99
      -- vim.o.foldenable = true
    end,
    -- stylua: ignore
    keys = {
      { "zR", function() require("ufo").openAllFolds() end },
      { "zM", function() require("ufo").closeAllFolds() end },
      { "zr", function() require("ufo").openFoldsExceptKinds() end },
      { "zm", function() require("ufo").closeFoldsWith() end },
      {
        "zK",
        function()
          local winid = require("ufo").peekFoldedLinesUnderCursor()
          if not winid then
            vim.lsp.buf.hover()
          end
        end,
      },
    },
    opts = function()
      -- -- kitty.conf
      -- vim.api.nvim_create_autocmd("BufReadPost", {
      --   callback = vim.schedule_wrap(function()
      --     if vim.wo.foldmethod == "marker" then
      --       require("ufo").closeAllFolds()
      --     end
      --   end),
      -- })

      -- add number suffix of folded lines
      local function virt_text_handler(virtText, lnum, endLnum, width, truncate)
        local newVirtText = {}
        local suffix = (" ⋯ %d "):format(endLnum - lnum)
        local sufWidth = vim.fn.strdisplaywidth(suffix)
        local targetWidth = width - sufWidth
        local curWidth = 0
        for _, chunk in ipairs(virtText) do
          local chunkText = chunk[1]
          local chunkWidth = vim.fn.strdisplaywidth(chunkText)
          if targetWidth > curWidth + chunkWidth then
            table.insert(newVirtText, chunk)
          else
            chunkText = truncate(chunkText, targetWidth - curWidth)
            local hlGroup = chunk[2]
            table.insert(newVirtText, { chunkText, hlGroup })
            chunkWidth = vim.fn.strdisplaywidth(chunkText)
            -- str width returned from truncate() may less than 2nd argument, need padding
            if curWidth + chunkWidth < targetWidth then
              suffix = suffix .. (" "):rep(targetWidth - curWidth - chunkWidth)
            end
            break
          end
          curWidth = curWidth + chunkWidth
        end
        table.insert(newVirtText, { suffix, "UfoFoldedEllipsis" })
        return newVirtText
      end

      --- (lsp -> treesitter -> indent) + marker
      ---@param bufnr number
      ---@return Promise
      local function selector(bufnr)
        local function handleFallbackException(err, providerName)
          if type(err) == "string" and err:match("UfoFallbackException") then
            return require("ufo").getFolds(bufnr, providerName)
          else
            return require("promise").reject(err)
          end
        end

        -- snacks bigfile: lsp -> indent
        local function is_bigfile(buf)
          return vim.bo[buf].filetype == "bigfile" or vim.b[buf].bigfile
        end

        return require("ufo")
          .getFolds(bufnr, "lsp")
          :catch(function(err)
            return is_bigfile(bufnr) and require("promise").reject(err) or handleFallbackException(err, "treesitter")
          end)
          :catch(function(err)
            return handleFallbackException(err, "indent")
          end)
          :thenCall(function(res)
            if is_bigfile(bufnr) then
              return res
            end
            -- alternative: require("ufo").getFolds(bufnr, "marker")
            -- NOTE: https://github.com/kevinhwang91/nvim-ufo/issues/233#issuecomment-2269229978
            -- PERF: https://github.com/kevinhwang91/nvim-ufo/issues/233#issuecomment-2226902851
            return res and vim.list_extend(res, require("ufo.provider.marker").getFolds(bufnr) or {})
          end, function(err)
            return require("promise").reject(err)
          end)
      end

      return {
        open_fold_hl_timeout = 150,
        provider_selector = function(bufnr, filetype, buftype)
          -- see also: https://github.com/chrisgrieser/.config/blob/9a3fa5f42f6b402a0eb2468f38b0642bbbe7ccef/nvim/lua/plugin-specs/ufo.lua#L37-L42
          local ftMap = {
            vim = "indent",
            python = { "indent" },
            git = "",
          }
          return ftMap[filetype] or selector
        end,
        close_fold_kinds_for_ft = {
          default = { "imports", "marker" }, -- comment
          -- json = { "array" },
          -- markdown = {}, -- avoid everything becoming folded
          -- toml = {},
        },
        fold_virt_text_handler = virt_text_handler,
        preview = {
          win_config = {
            -- border = { "", "─", "", "", "", "─", "", "" },
            winblend = 0,
          },
          mappings = {
            scrollU = "<C-b>",
            scrollD = "<C-f>",
            jumpTop = "[",
            jumpBot = "]",
          },
        },
      }
    end,
  },

  {
    "max397574/better-escape.nvim",
    event = { "InsertEnter", "CmdlineEnter" },
    opts = {
      default_mappings = false, -- j/k navigation in lazygit and fzf-lua
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

  -- alternative: https://github.com/xzbdmw/nvimconfig/blob/0be9805dac4661803e17265b435060956daee757/lua/theme/dark.lua#L23
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
            { desc = "Double to Exit" },
          },
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
