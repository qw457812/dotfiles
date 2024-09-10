return {
  -- https://github.com/liubang/nvimrc/blob/e7dbb3f5193728b59dbfff5dcd5b3756c5ed1585/lua/plugins/neo-tree-nvim.lua
  -- https://github.com/Matt-FTW/dotfiles/blob/main/.config/nvim/lua/plugins/extras/editor/neo-tree-extended.lua
  -- https://github.com/GentleCold/dotfiles/blob/5104ac8fae45b68a33c973a19b1f6a2e0617d400/.config/nvim/lua/plugins/dir_tree.lua
  -- https://github.com/nvim-lua/kickstart.nvim/blob/master/lua/kickstart/plugins/neo-tree.lua
  -- https://github.com/rafi/vim-config/blob/b9648dcdcc6674b707b963d8de902627fbc887c8/lua/rafi/plugins/neo-tree.lua
  -- https://github.com/aimuzov/LazyVimx/blob/789dafed84f6f61009f13b4054f12208842df225/lua/lazyvimx/extras/ui/panels/explorer.lua
  {
    "nvim-neo-tree/neo-tree.nvim",
    dependencies = { "echasnovski/mini.icons" },
    keys = function(_, keys)
      LazyVim.toggle.map("<leader>uz", {
        name = "NeoTree Auto Close",
        get = function()
          return vim.g.user_neotree_auto_close
        end,
        set = function(state)
          vim.g.user_neotree_auto_close = state
          require("neo-tree.command").execute({ action = state and "close" or "show" })
        end,
      })

      local last_root ---@type string?
      local mappings = {
        {
          "<leader>fe",
          function()
            -- https://github.com/AstroNvim/AstroNvim/blob/c7abf1c198f633574060807a181c6ce4d1c53a2c/lua/astronvim/plugins/neo-tree.lua#L14
            if vim.bo.filetype == "neo-tree" then
              if vim.g.user_neotree_auto_close then
                require("neo-tree.command").execute({ action = "close" })
              else
                vim.cmd("wincmd p")
              end
              return
            end

            -- reveal the current file in root directory, or if in an unsaved file, the current working directory
            -- :h neo-tree-configuration
            local command = require("neo-tree.command")
            local reveal_file = vim.fn.expand("%:p")
            if reveal_file == "" then
              reveal_file = vim.fn.getcwd()
            else
              -- alternative to `vim.fn.filereadable(reveal_file)`?
              local f = io.open(reveal_file, "r")
              if f then
                f.close(f)
              else
                reveal_file = vim.fn.getcwd()
              end
            end

            local function reveal_without_set_root()
              command.execute({ reveal_file = reveal_file, reveal_force_cwd = true })
            end

            -- workaround below not working in termux
            if vim.g.user_is_termux then
              reveal_without_set_root()
              return
            end

            local root = LazyVim.root()
            if not vim.startswith(reveal_file, root) then
              last_root = nil -- neo-tree's root will change after reveal
              reveal_without_set_root() -- wrong root, reveal only
              return
            end

            local function execute(action)
              command.execute({
                action = action,
                -- reveal = true, -- using `reveal_file` to reveal cwd if unsaved
                reveal_file = reveal_file, -- path to file or folder to reveal
                reveal_force_cwd = true, -- change cwd without asking if needed
                dir = root,
              })
            end

            if last_root == root then
              execute()
            else
              last_root = root -- cache
              -- workaround for `reveal_force_cwd` + `dir`, execute twice to properly set root dir (base on my test only)
              execute("show")
              vim.defer_fn(function()
                execute()
              end, 100)
            end
          end,
          desc = "Explorer NeoTree (Root Dir)",
        },
        -- stylua: ignore start
        { "<leader>fE", function() require("neo-tree.command").execute({ dir = vim.uv.cwd() }) end, desc = "Explorer NeoTree (cwd)" },
        -- { "<leader>ge", function() require("neo-tree.command").execute({ source = "git_status" }) end, desc = "Git Explorer" },
        -- { "<leader>be", function() require("neo-tree.command").execute({ source = "buffers" }) end, desc = "Buffer Explorer" },
        -- stylua: ignore end
        { "<leader>ge", false },
        { "<leader>be", false },
      }

      local opts = LazyVim.opts("neo-tree.nvim")
      if opts.filesystem.hijack_netrw_behavior ~= "disabled" then
        vim.list_extend(mappings, {
          { "-", "<leader>fe", desc = "Explorer NeoTree (Root Dir)", remap = true },
        })
      end
      return vim.list_extend(keys, mappings)
    end,
    opts = {
      sources = { "filesystem" },
      close_if_last_window = true, -- close Neo-tree if it is the last window left in the tab
      default_component_configs = {
        -- use mini.icons instead of nvim-web-devicons
        -- https://github.com/nvim-neo-tree/neo-tree.nvim/pull/1527#issuecomment-2233186777
        icon = {
          provider = function(icon, node)
            if node.type == "file" or node.type == "directory" then
              local text, hl = require("mini.icons").get(node.type, node.name)
              icon.highlight = hl
              -- for directory, only set the icon text if it is not expanded
              if node.type == "file" or not node:is_expanded() then
                icon.text = text
              end
            end
          end,
        },
        kind_icon = {
          provider = function(icon, node)
            icon.text, icon.highlight = require("mini.icons").get("lsp", node.extra.kind.name)
          end,
        },
      },
      commands = {
        unfocus_window = function(state)
          vim.cmd.wincmd(state.current_position == "left" and "l" or "p")
        end,
        close_or_unfocus = function(state)
          state.commands[vim.g.user_neotree_auto_close and "close_window" or "unfocus_window"](state)
        end,
        cancel_or_close_or_unfocus = function(state)
          local preview = require("neo-tree.sources.common.preview")
          -- copied from: https://github.com/nvim-neo-tree/neo-tree.nvim/blob/206241e451c12f78969ff5ae53af45616ffc9b72/lua/neo-tree/sources/common/commands.lua#L653
          local has_preview = preview.is_active()
          local has_floating = state.current_position == "float"
          local has_filter = state.name == "filesystem" and state.search_pattern ~= nil
          if has_preview or has_floating or has_filter then
            -- original behavior of <esc> is `cancel`: close preview or floating neo-tree window
            -- require("neo-tree.sources.common.commands").cancel(state)
            if has_preview then
              preview.hide()
            end
            if has_floating then
              require("neo-tree.ui.renderer").close_all_floating_windows()
            end
            if has_filter then
              require("neo-tree.sources.filesystem.commands").clear_filter(state)
            end
          else
            -- close_or_unfocus if nothing to do
            -- like Lazygit's `quitOnTopLevelReturn`: https://github.com/jesseduffield/lazygit/blob/753b16b6970dbfcbe2c4349bbcdea85587ea51f7/docs/Config.md?plain=1#L386
            state.commands["close_or_unfocus"](state)
          end
        end,
        -- https://github.com/AstroNvim/AstroNvim/blob/c7abf1c198f633574060807a181c6ce4d1c53a2c/lua/astronvim/plugins/neo-tree.lua#L113
        parent_or_close = function(state)
          local node = state.tree:get_node()
          if node:has_children() and node:is_expanded() then
            state.commands.toggle_node(state)
          else
            require("neo-tree.ui.renderer").focus_node(state, node:get_parent_id())
          end
        end,
        child_or_open = function(state)
          local node = state.tree:get_node()
          if node:has_children() then
            if not node:is_expanded() then -- if unexpanded, expand
              state.commands.toggle_node(state)
            else -- if expanded and has children, seleect the next child
              if node.type == "file" then
                state.commands.open(state)
              else
                require("neo-tree.ui.renderer").focus_node(state, node:get_child_ids()[1])
              end
            end
          else -- if has no children
            state.commands.open(state)
          end
        end,
        copy_selector = function(state)
          local node = state.tree:get_node()
          local filepath = node:get_id()
          local filename = node.name
          local modify = vim.fn.fnamemodify

          local vals = {
            ["BASENAME"] = modify(filename, ":r"),
            ["EXTENSION"] = modify(filename, ":e"),
            ["FILENAME"] = filename,
            ["PATH (CWD)"] = modify(filepath, ":."),
            ["PATH (HOME)"] = modify(filepath, ":~"),
            ["PATH"] = filepath,
            ["URI"] = vim.uri_from_fname(filepath),
          }

          local options = vim.tbl_filter(function(val)
            return vals[val] ~= ""
          end, vim.tbl_keys(vals))
          if vim.tbl_isempty(options) then
            LazyVim.warn("No values to copy", { title = "Neo-tree" })
            return
          end
          table.sort(options)
          vim.ui.select(options, {
            prompt = "Choose to copy to clipboard:",
            format_item = function(item)
              return ("%s: %s"):format(item, vals[item])
            end,
          }, function(choice)
            local result = vals[choice]
            if result then
              LazyVim.info(("Copied: `%s`"):format(result), { title = "Neo-tree" })
              vim.fn.setreg("+", result)
            end
          end)
        end,
        find_in_dir = function(state)
          local node = state.tree:get_node()
          local path = node.type == "file" and node:get_parent_id() or node:get_id()
          LazyVim.pick("files", { cwd = path })()
        end,
      },
      window = {
        mappings = {
          ["-"] = "close_or_unfocus", -- toggle neo-tree, work with `-` defined in `keys` above
          ["<esc>"] = {
            "cancel_or_close_or_unfocus",
            desc = "cancel / close_or_unfocus",
          },
          ["h"] = "parent_or_close",
          ["l"] = "child_or_open",
          ["Y"] = "copy_selector",
          ["F"] = "find_in_dir",
          ["<tab>"] = {
            function(state)
              local node = state.tree:get_node()
              if require("neo-tree.utils").is_expandable(node) then
                state.commands["toggle_node"](state)
              else
                state.commands["open"](state)
                vim.cmd("Neotree reveal")
              end
            end,
            desc = "Open without focus",
          },
        },
        fuzzy_finder_mappings = { -- define keymaps for filter popup window in fuzzy_finder_mode
          ["<C-j>"] = "move_cursor_down",
          ["<C-k>"] = "move_cursor_up",
        },
      },
      filesystem = {
        filtered_items = {
          hide_dotfiles = false,
          hide_gitignored = false,
          hide_hidden = false,
          hide_by_name = {
            -- "node_modules",
            -- ".git",
          },
          never_show = {
            ".DS_Store",
            "thumbs.db",
          },
        },
        -- whether to use for editing directories (e.g. `vim .` or `:e src/`)
        -- possible values: "open_default" (default), "open_current", "disabled"
        -- hijack_netrw_behavior = "disabled", -- netrw left alone, neo-tree does not handle opening dirs
        window = {
          -- TODO: unify the keybindings of vifm (or yazi) and neo-tree.nvim
          mappings = {
            -- ["<esc>"] = {
            --   function(state)
            --     require("neo-tree.sources.common.commands").cancel(state) -- close preview or floating neo-tree window
            --     require("neo-tree.sources.filesystem.commands").clear_filter(state)
            --   end,
            --   desc = "cancel + clear_filter",
            -- },
            ["<esc>"] = {
              "cancel_or_close_or_unfocus",
              desc = "(cancel + clear_filter) / close_or_unfocus",
            },
            -- https://github.com/nvim-neo-tree/neo-tree.nvim/wiki/Tips#navigation-with-hjkl
            ["h"] = {
              function(state)
                local node = state.tree:get_node()
                if node.type == "directory" and node:is_expanded() and node:has_children() then
                  require("neo-tree.sources.filesystem").toggle_directory(state, node)
                elseif node:get_depth() == 1 then
                  require("neo-tree.sources.filesystem.commands").navigate_up(state)
                else
                  require("neo-tree.ui.renderer").focus_node(state, node:get_parent_id())
                end
              end,
              desc = "focus parent / close_node / navigate_up",
            },
            ["l"] = {
              function(state)
                local node = state.tree:get_node()
                if node.type == "directory" then
                  if not node:is_expanded() then
                    require("neo-tree.sources.filesystem").toggle_directory(state, node)
                  elseif node:has_children() then
                    require("neo-tree.ui.renderer").focus_node(state, node:get_child_ids()[1])
                  end
                else
                  require("neo-tree.sources.filesystem.commands").open(state)
                end
              end,
              desc = "expand node / focus first child / open",
            },
          },
        },
      },
      -- buffers = {
      --   window = {
      --     mappings = {
      --       ["bd"] = "none", -- use `d` instead
      --       ["d"] = "buffer_delete",
      --     },
      --   },
      -- },
      event_handlers = {
        -- https://github.com/nvim-neo-tree/neo-tree.nvim/wiki/Recipes#auto-close-on-open-file
        -- alternative: https://github.com/nvim-neo-tree/neo-tree.nvim/issues/344
        {
          event = "file_opened",
          handler = function(file_path)
            if vim.g.user_neotree_auto_close then
              -- auto close on open file
              require("neo-tree.command").execute({ action = "close" })
            end
          end,
        },
        {
          event = "neo_tree_popup_input_ready",
          ---@param args { bufnr: integer, winid: integer }
          handler = function(args)
            -- map <esc> to enter normal mode of NuiInput (by default closes prompt)
            vim.keymap.set("i", "<esc>", vim.cmd.stopinsert, { noremap = true, buffer = args.bufnr })
          end,
        },
      },
    },
  },

  {
    "folke/flash.nvim",
    optional = true,
    keys = function(_, keys)
      -- https://github.com/JoseConseco/nvim_config/blob/23dbf5f8b9779d792643ab5274ebe8dabe79c0c0/lua/plugins.lua#L1049
      -- https://github.com/mfussenegger/nvim-treehopper
      ---@param skip_first_match? boolean
      local function treesitter(skip_first_match)
        require("flash").treesitter({
          ---@param matches Flash.Match.TS[]
          filter = function(matches)
            if skip_first_match then
              -- before removing first match, match[n+1] should use previous match[n] label
              for i = #matches, 2, -1 do
                matches[i].label = matches[i - 1].label
              end
              -- remove first match, as it is same as word under cursor (not always) thus redundant with word motion
              table.remove(matches, 1)
            end
            return matches
          end,
          label = { rainbow = { enabled = true } },
        })
      end

      -- stylua: ignore
      return vim.list_extend(keys, {
        { "S", mode = { "n", "o", "x" }, function() treesitter() end, desc = "Flash Treesitter" },
        { "u", mode = { "o", "x" }, function() treesitter(true) end, desc = "Flash Treesitter" }, -- unit textobject
        -- {
        --   "R",
        --   mode = { "o", "x" },
        --   function()
        --     require("flash").treesitter_search({ label = { rainbow = { enabled = true } } })
        --   end,
        --   desc = "Treesitter Search",
        -- },
      })
    end,
  },

  -- {
  --   "folke/which-key.nvim",
  --   opts = {
  --     win = {
  --       no_overlap = false, -- don't allow the popup to overlap with the cursor
  --     },
  --   },
  -- },

  -- https://github.com/linkarzu/dotfiles-latest/blob/66c7304d34c713e8c7d6066d924ac2c3a9c0c9e8/neovim/neobean/lua/plugins/mini-files.lua
  -- https://github.com/mrjones2014/dotfiles/blob/62cd7b9c034b04daff4a2b38ad9eac0c9dcb43e1/nvim/lua/my/configure/mini_files.lua
  {
    "echasnovski/mini.files",
    optional = true,
    opts = function(_, opts)
      opts.mappings = vim.tbl_deep_extend("force", opts.mappings or {}, {
        go_in = "",
        go_out = "",
        go_in_plus = "l", -- go_in + close explorer after opening a file
        go_out_plus = "h", -- go_out + trim right part of branch
        -- -- don't use `h`/`l` for easier cursor navigation during text edit
        -- go_in_plus = "L",
        -- go_out_plus = "H",
      })
      -- opts.windows = vim.tbl_deep_extend("force", opts.windows or {}, {
      --   width_preview = 60,
      -- })

      vim.api.nvim_create_autocmd("User", {
        pattern = "MiniFilesBufferCreate",
        callback = function(args)
          local buf_id = args.data.buf_id

          -- stylua: ignore start
          vim.keymap.set("n", "<cr>", function() require("mini.files").go_in({ close_on_file = true }) end, { buffer = buf_id, desc = "Go in plus (mini.files)" })
          vim.keymap.set("n", "<leader>fs", function() require("mini.files").synchronize() end, { buffer = buf_id, desc = "Synchronize (mini.files)" })
          vim.keymap.set("n", "<C-s>", function() require("mini.files").synchronize() end, { buffer = buf_id, desc = "Synchronize (mini.files)" })
          -- stylua: ignore end
          -- cursor navigation during text edit
          vim.keymap.set("n", "H", "h", { buffer = buf_id, desc = "<Left>" })
          vim.keymap.set("n", "L", "l", { buffer = buf_id, desc = "<Right>" })
        end,
      })

      -- set custom bookmarks
      local set_mark = function(id, path, desc)
        MiniFiles.set_bookmark(id, path, { desc = desc })
      end
      vim.api.nvim_create_autocmd("User", {
        pattern = "MiniFilesExplorerOpen",
        callback = function()
          set_mark("c", U.path.config, "Config") -- path
          set_mark("w", vim.fn.getcwd, "cwd") -- callable
          set_mark("h", "~", "Home")
          -- stylua: ignore
          set_mark("r", function() return LazyVim.root.get({ normalize = true }) end, "Root")
          set_mark("l", U.path.lazyvim, "LazyVim")
          if U.path.chezmoi then
            set_mark("z", U.path.chezmoi, "Chezmoi")
          end
        end,
      })
    end,
  },

  -- {
  --   "RRethy/vim-illuminate",
  --   optional = true,
  --   opts = function(_, opts)
  --     -- -- base on tokyonight-moon
  --     -- local illuminate = "#51576d"
  --     -- -- remove `default = true,` to override colorscheme's highlight group
  --     -- vim.api.nvim_set_hl(0, "IlluminatedWordText", { default = true, bg = "#3b4261" })
  --     -- vim.api.nvim_set_hl(0, "IlluminatedWordRead", { default = true, bg = illuminate })
  --     -- vim.api.nvim_set_hl(0, "IlluminatedWordWrite", { default = true, bg = illuminate, underline = true })
  --     opts.filetypes_denylist = vim.list_extend(opts.filetypes_denylist or { "dirbuf", "dirvish", "fugitive" }, {
  --       "lazy",
  --       "mason",
  --       "harpoon",
  --       "qf",
  --       "netrw",
  --       "neo-tree",
  --       "oil",
  --       "minifiles",
  --       "trouble",
  --       "notify",
  --       "TelescopePrompt",
  --     })
  --   end,
  -- },

  -- alternative: https://github.com/xzbdmw/nvimconfig/blob/0be9805dac4661803e17265b435060956daee757/lua/theme/dark.lua#L23
  {
    "LazyVim/LazyVim",
    dependencies = {
      { "debugloop/layers.nvim", opts = {} },
    },
    keys = {
      -- stylua: ignore
      { "M", function() PAGER_MODE:toggle() end, desc = "Pager Mode" },
    },
    opts = function()
      if vim.g.vscode then
        return
      end

      ---@diagnostic disable-next-line: undefined-global
      PAGER_MODE = Layers.mode.new()
      PAGER_MODE:auto_show_help()
      PAGER_MODE:keymaps({
        n = {
          { "u", "<C-u>", { desc = "Scroll Up" } },
          -- { "d", "<C-d>", { desc = "Scroll Down", nowait = true } },
          { "d", "<C-d>", { desc = "Scroll Down" } },
          -- stylua: ignore
          { "<esc>", function() PAGER_MODE:deactivate() end, { desc = "Exit" } },
        },
      })
      local orig_dd_keymap ---@type table<string,any>
      local orig_minianimate_disable ---@type boolean?
      PAGER_MODE:add_hook(function(active)
        if active then
          -- remove `dd` mapping, defined in ../config/keymaps.lua
          -- https://github.com/debugloop/layers.nvim/blob/67666f59a2dbe36a469766be6a4c484ae98c4895/lua/layers/map.lua#L52
          orig_dd_keymap = vim.fn.maparg("dd", "n", false, true) --[[@as table<string,any>]]
          if not vim.tbl_isempty(orig_dd_keymap) then
            vim.keymap.del("n", "dd")
          end
          -- disable mini.animate
          orig_minianimate_disable = vim.g.minianimate_disable
          vim.g.minianimate_disable = true
        else
          if not vim.tbl_isempty(orig_dd_keymap) then
            vim.fn.mapset(orig_dd_keymap)
          end
          vim.g.minianimate_disable = orig_minianimate_disable
        end
      end)
    end,
  },

  -- https://github.com/sxyazi/dotfiles/blob/18ce3eda7792df659cb248d9636b8d7802844831/nvim/lua/plugins/ui.lua#L646
  {
    "mikavilpas/yazi.nvim",
    keys = {
      { "<leader><cr>", "<cmd>Yazi<cr>", desc = "Yazi (Buffer Dir)" },
    },
    opts = function()
      vim.api.nvim_create_autocmd("TermOpen", {
        callback = function(event)
          local buf = event.buf
          if vim.bo[buf].filetype == "yazi" then
            -- esc_esc = false
            vim.keymap.set("t", "<esc>", "<esc>", { buffer = buf, nowait = true })
            -- ctrl_hjkl = false
            vim.keymap.set("t", "<c-h>", "<c-h>", { buffer = buf, nowait = true })
            vim.keymap.set("t", "<c-j>", "<c-j>", { buffer = buf, nowait = true })
            vim.keymap.set("t", "<c-k>", "<c-k>", { buffer = buf, nowait = true })
            vim.keymap.set("t", "<c-l>", "<c-l>", { buffer = buf, nowait = true })
          end
        end,
      })
    end,
  },

  -- for escaping easily from insert mode
  {
    "max397574/better-escape.nvim",
    event = "VeryLazy",
    opts = {
      -- note: lazygit, fzf-lua use terminal mode, `jj` and `jk` make lazygit navigation harder
      default_mappings = false,
      mappings = {
        i = {
          j = {
            -- these can all also be functions
            k = "<Esc>",
            j = "<Esc>",
          },
          k = {
            j = "<Esc>",
          },
        },
        c = {
          j = {
            k = "<Esc>",
            j = "<Esc>",
          },
          k = {
            j = "<Esc>",
          },
        },
      },
    },
  },

  -- better `:substitute`
  {
    "chrisgrieser/nvim-rip-substitute",
    cmd = "RipSubstitute",
    keys = {
      {
        "<leader>sf",
        function()
          require("rip-substitute").sub()
        end,
        mode = { "n", "x" },
        desc = " rip substitute",
      },
    },
    -- opts = {
    --   popupWin = {
    --     position = "top",
    --   },
    -- },
  },

  {
    "tzachar/highlight-undo.nvim",
    event = "VeryLazy",
    vscode = true,
    opts = function()
      -- link: Search IncSearch Substitute
      vim.api.nvim_set_hl(0, "HighlightUndo", { default = true, link = "Substitute" })
      vim.api.nvim_set_hl(0, "HighlightRedo", { default = true, link = "HighlightUndo" })
      return {
        --[[add custom config here]]
      }
    end,
  },

  -- TODO: choose motion plugin between: flash, leap, hop
  -- https://github.com/doctorfree/nvim-lazyman/blob/bb4091c962e646c5eb00a50eca4a86a2d43bcb7c/lua/ecovim/config/plugins.lua#L373
  -- "remote flash" for leap: https://github.com/rasulomaroff/telepath.nvim
}
