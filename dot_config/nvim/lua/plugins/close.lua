local close_key, exit_key, term_close_key = vim.g.user_close_key, vim.g.user_exit_key, vim.g.user_term_close_key
if not close_key then
  vim.notify("`vim.g.user_close_key` is required", vim.log.levels.WARN, { title = "Close" })
  return {}
end

-- TODO: find a key to close window(/buffer or exit)

-- do not use `clear = true` at the top-level, it will be triggered by lazy.nvim on `Config Change Detected. Reloading...`
local augroup = vim.api.nvim_create_augroup("close_with_" .. close_key, { clear = false })

-- copied from: https://github.com/psjay/buffer-closer.nvim/blob/74fec63c4c238b2cf6f61c40b47f869d442a8988/lua/buffer-closer/init.lua#L10
-- https://github.com/chrisgrieser/.config/blob/88eb71f88528f1b5a20b66fd3dfc1f7bd42b408a/nvim/lua/funcs/alt-alt.lua#L42
-- see also: https://github.com/folke/sidekick.nvim/commit/99824c2b63d547a1fd90e24fa9e8fb648382645d
local function close_buffer_or_window_or_exit()
  if vim.g.vscode then
    local vscode = require("vscode")
    vscode.call("workbench.action.unpinEditor")
    vscode.action("workbench.action.closeActiveEditor") -- can not close pinned editor
    return
  end

  local function listed_buffers()
    -- return vim.fn.getbufinfo({ buflisted = 1 })
    return vim.tbl_filter(function(b)
      return vim.api.nvim_buf_is_valid(b) and vim.bo[b].buflisted
    end, vim.api.nvim_list_bufs())
  end

  -- https://github.com/nvim-neo-tree/neo-tree.nvim/blob/42caaf5c3b7ca346ab278201151bb878006a6031/lua/neo-tree/utils/init.lua#L533
  -- https://github.com/folke/sidekick.nvim/commit/d72c611aa37b24d8ad401c4029d8946e27f53475
  local function non_real_file()
    return vim.bo.buftype ~= ""
  end

  -- https://github.com/nvim-neo-tree/neo-tree.nvim/blob/42caaf5c3b7ca346ab278201151bb878006a6031/lua/neo-tree/utils/init.lua#L520
  local function is_winfixbuf()
    return vim.fn.exists("&winfixbuf") == 1 and vim.wo.winfixbuf
  end

  -- known window types: main, floating and edgy
  -- use `:close` for floating and edgy (redundant with edgy's Lazy Spec below)
  -- use `:bd` (or `:qa` if no listed buffer left) for main
  -- https://github.com/folke/edgy.nvim/blob/ebb77fde6f5cb2745431c6c0fe57024f66471728/lua/edgy/editor.lua#L82
  if U.is_floating_win() then
    vim.cmd("close") -- Close Window (Cannot close last window)
  elseif #listed_buffers() > (vim.bo.buflisted and 1 or 0) then
    if
      non_real_file()
      or is_winfixbuf()
      or (#vim.api.nvim_list_tabpages() > 1 and #vim.api.nvim_tabpage_list_wins(0) == 1)
    then
      vim.cmd("bd") -- Delete Buffer and Window
    else
      Snacks.bufdelete() -- Delete Buffer
    end
  else
    vim.cmd("qa")
  end
end

---@type LazySpec
return {
  {
    "LazyVim/LazyVim",
    keys = function(_, keys)
      vim.list_extend(keys, {
        { close_key, close_buffer_or_window_or_exit, desc = "Close buffer/window or Exit" },
        { close_key, mode = "x", "<esc>", desc = "Stop Visual Mode" },
      })
      if exit_key then
        table.insert(keys, {
          exit_key,
          vim.g.vscode and function()
            require("vscode").action("workbench.action.closeWindow")
          end or "<cmd>qa<cr>",
          desc = "Quit All",
        })
      end
      if term_close_key then
        vim.list_extend(keys, {
          { term_close_key, mode = "t", "<cmd>bd!<cr>", desc = "Close terminal" }, -- <cmd>close<cr>
          { term_close_key, close_key, desc = "Close buffer/window or Exit", remap = true },
        })
      end
      return keys
    end,
    opts = function()
      if close_key:lower() == "<bs>" then
        if not package.loaded["mini.pairs"] then
          vim.keymap.set("c", "<bs>", function()
            if vim.fn.getcmdline() ~= "" then
              return "<bs>"
            end
          end, { expr = true, desc = "<bs> does not leave cmdline" })
        end

        if LazyVim.has("mini.pairs") then
          LazyVim.on_load(
            "mini.pairs",
            vim.schedule_wrap(function()
              local pairs = require("mini.pairs")
              local c_pairs_bs = pairs.config.modes.command
              -- see: https://github.com/nvim-mini/mini.pairs/blob/7e834c5937d95364cc1740e20d673afe2d034cdb/lua/mini/pairs.lua#L574C5-L576C54
              vim.keymap.set("c", "<bs>", function()
                if vim.fn.getcmdline() ~= "" then
                  return c_pairs_bs and pairs.bs() or "<bs>"
                end
              end, {
                expr = true,
                silent = false,
                replace_keycodes = not c_pairs_bs,
                desc = string.format("%s does not leave cmdline", c_pairs_bs and "MiniPairs.bs()" or "<bs>"),
              })
            end)
          )
        end

        vim.api.nvim_create_autocmd("TermOpen", {
          group = augroup,
          pattern = "*lazygit",
          callback = function(event)
            -- mapped <c-h> to quit in lazygit/config.yml via `quitWithoutChangingDirectory: <backspace>`
            -- when typing a commit message in lazygit, <c-h> and <bs> do the same thing
            vim.keymap.set("t", "<bs>", "<C-h>", {
              buffer = event.buf,
              silent = true,
              desc = "Quit Lazygit",
            })
          end,
        })
      end

      vim.api.nvim_create_autocmd("CmdWinEnter", {
        group = augroup,
        callback = function(event)
          vim.keymap.set("n", close_key, "<cmd>q<cr>", {
            buffer = event.buf,
            silent = true,
            desc = "Close command-line window",
          })
        end,
      })

      -- vim.api.nvim_create_autocmd("FileType", {
      --   group = augroup,
      --   pattern = "gitcommit",
      --   callback = function(ev)
      --     if vim.fn.fnamemodify(ev.file, ":t") == "COMMIT_EDITMSG" then
      --       vim.keymap.set("n", close_key, function()
      --         -- clear any changes (avoid `Save changes to ".git/COMMIT_EDITMSG"?`)
      --         vim.cmd("edit! " .. ev.file)
      --         close_buffer_or_window_or_exit()
      --       end, { buffer = ev.buf, silent = true, desc = "Force Close (Git Commit)" })
      --     end
      --   end,
      -- })

      if LazyVim.has("vim-dadbod-ui") then
        LazyVim.on_load("vim-dadbod-ui", function()
          if vim.g.db_ui_tmp_query_location then
            vim.api.nvim_create_autocmd("BufNewFile", {
              group = augroup,
              pattern = vim.g.db_ui_tmp_query_location .. "/*",
              callback = function(event)
                vim.keymap.set("n", close_key, function()
                  -- do not ask for saving changes
                  Snacks.bufdelete({ buf = event.buf, force = true })
                end, {
                  buffer = event.buf,
                  silent = true,
                  desc = "Force Quit",
                })
              end,
            })
          end
        end)
      end
    end,
  },

  {
    "folke/edgy.nvim",
    optional = true,
    opts = {
      keys = {
        [close_key] = function(win)
          win:close()
        end,
      },
    },
  },

  {
    "folke/snacks.nvim",
    optional = true,
    ---@module "snacks"
    ---@type snacks.Config
    opts = {
      win = {
        keys = {
          -- trigger opts.autowrite of Snacks.scratch
          [close_key] = {
            close_key,
            function(self)
              -- fix: close_key not working after closing zen
              if vim.api.nvim_get_current_win() == self.win then
                self:close()
              else
                close_buffer_or_window_or_exit()
              end
            end,
            desc = "Close",
          },
        },
      },
      -- override the opts.win.keys to avoid exiting terminal
      terminal = {
        win = {
          keys = {
            [close_key] = "hide",
            term_close = term_close_key and {
              term_close_key,
              function(self)
                self:hide()
              end,
              mode = "t",
              desc = "Close",
            } or nil,
          },
        },
      },
      picker = {
        win = {
          input = {
            keys = {
              [close_key] = "close", -- cancel
            },
          },
          list = {
            keys = {
              [close_key] = "close",
            },
          },
          preview = {
            keys = {
              [close_key] = "close",
            },
          },
        },
        sources = {
          explorer = {
            win = {
              list = {
                keys = {
                  [close_key] = "close",
                },
              },
            },
          },
        },
      },
    },
  },

  {
    "folke/sidekick.nvim",
    optional = true,
    ---@module "sidekick"
    ---@type sidekick.Config
    opts = {
      cli = {
        win = {
          ---@type table<string, sidekick.cli.Keymap|false>
          keys = {
            [close_key] = { close_key, "hide", mode = "n" },
            term_close = term_close_key and { term_close_key, "hide" } or nil,
          },
        },
      },
    },
  },

  {
    "nvim-neo-tree/neo-tree.nvim",
    optional = true,
    ---@module "neo-tree"
    ---@type neotree.Config
    opts = {
      window = {
        mappings = {
          [close_key] = "close_window",
        },
      },
      filesystem = {
        window = {
          mappings = {
            [close_key] = "close_window",
          },
        },
      },
      buffers = {
        window = {
          mappings = {
            [close_key] = "close_window",
          },
        },
      },
      git_status = {
        window = {
          mappings = {
            [close_key] = "close_window",
          },
        },
      },
      document_symbols = {
        window = {
          mappings = {
            [close_key] = "close_window",
          },
        },
      },
    },
  },
  {
    "nvim-neo-tree/neo-tree.nvim",
    optional = true,
    opts = function()
      vim.api.nvim_create_autocmd("FileType", {
        group = augroup,
        pattern = "neo-tree-popup",
        callback = function(event)
          vim.defer_fn(function()
            vim.keymap.set("n", close_key, function()
              -- HACK: trigger `BufLeave` of nui to close
              -- https://github.com/nvim-neo-tree/neo-tree.nvim/blob/d175a0ce24bcb022ec1c93635841c043d764418e/lua/neo-tree/sources/filesystem/lib/filter.lua#L203
              vim.cmd("wincmd p")
            end, { buffer = event.buf, desc = "Close (NeoTree Popup)" })
          end, 100)
        end,
      })
      vim.api.nvim_create_autocmd("FileType", {
        group = augroup,
        pattern = "neo-tree",
        callback = function(event)
          -- HACK: sometimes <bs> is mapped to `navigate_up` instead of `close_window`
          vim.defer_fn(function()
            vim.keymap.set("n", close_key, function()
              -- HACK: make <bs> close neotree even if vim.g.user_explorer_auto_open is true
              if vim.g.user_explorer_auto_open then
                local ei = vim.o.eventignore
                vim.o.eventignore = "WinResized" -- for augroup: resize_neotree_auto_open_or_close
                vim.schedule(function()
                  vim.o.eventignore = ei
                end)
              end
              return "q"
            end, { buffer = event.buf, remap = true, expr = true, desc = "Close (NeoTree)" })
          end, 100)
        end,
      })
    end,
  },

  {
    "nvim-telescope/telescope.nvim",
    optional = true,
    opts = {
      defaults = {
        mappings = {
          n = {
            [close_key] = "close",
          },
        },
      },
    },
  },

  {
    "folke/noice.nvim",
    optional = true,
    opts = function(_, opts)
      local defaults_views = require("noice.config.views").defaults
      opts.views = vim.tbl_deep_extend("force", {
        split = {
          close = {
            keys = vim.deepcopy(defaults_views.split.close.keys),
          },
        },
        popup = {
          close = {
            keys = vim.deepcopy(defaults_views.popup.close.keys),
          },
        },
      }, opts.views or {})

      table.insert(opts.views.split.close.keys, close_key)
      table.insert(opts.views.popup.close.keys, close_key)
    end,
  },

  {
    "folke/trouble.nvim",
    optional = true,
    opts = {
      keys = {
        [close_key] = "close",
      },
    },
  },

  {
    "stevearc/oil.nvim",
    optional = true,
    opts = {
      keymaps = {
        [close_key] = {
          "actions.close",
          opts = { exit_if_last_buf = true },
          mode = "n",
          desc = "Close or Exit",
        },
      },
    },
  },

  {
    "nvim-mini/mini.files",
    optional = true,
    opts = function(_, opts)
      vim.api.nvim_create_autocmd("User", {
        group = augroup,
        pattern = "MiniFilesBufferCreate",
        callback = function(args)
          local buf_id = args.data.buf_id
          -- stylua: ignore
          vim.keymap.set("n", close_key, function() require("mini.files").close() end, { buffer = buf_id, desc = "Close (mini.files)" })
        end,
      })

      opts.mappings = opts.mappings or {}
      if not opts.mappings.reset or Snacks.util.normkey(opts.mappings.reset) == Snacks.util.normkey(close_key) then
        opts.mappings.reset = ""
      end
    end,
  },

  {
    "Bekaboo/dropbar.nvim",
    optional = true,
    opts = {
      menu = {
        keymaps = {
          [close_key] = function()
            local menu = require("dropbar.utils.menu").get_current()
            while menu and menu.prev_menu do
              menu = menu.prev_menu
            end
            if menu then
              menu:close()
            end
          end,
        },
      },
    },
  },

  {
    "oysandvik94/curl.nvim",
    optional = true,
    opts = function()
      vim.api.nvim_create_autocmd("FileType", {
        group = augroup,
        pattern = "curl",
        callback = function(event)
          vim.keymap.set("n", close_key, "<cmd>CurlClose<cr>", {
            buffer = event.buf,
            silent = true,
            desc = "Close (curl.nvim)",
          })
        end,
      })
    end,
  },

  {
    "potamides/pantran.nvim",
    optional = true,
    opts = function(_, opts)
      local actions = require("pantran.ui.actions")

      opts.controls = vim.tbl_deep_extend("force", {
        mappings = {
          edit = {
            n = {
              [close_key] = actions.close,
            },
          },
        },
      }, opts.controls or {})
    end,
  },

  {
    "kawre/leetcode.nvim",
    optional = true,
    opts = function(_, opts)
      opts.keys = opts.keys or {}
      opts.keys.toggle = type(opts.keys.toggle) == "table" and opts.keys.toggle or { opts.keys.toggle or "q" }
      table.insert(opts.keys.toggle, close_key)
    end,
  },

  {
    "kristijanhusak/vim-dadbod-ui",
    optional = true,
    keys = {
      { close_key, "<Plug>(DBUI_Quit)", desc = "Quit (dadbod)", ft = "dbui" },
      { close_key, "<cmd>bd<cr>", desc = "Close (dadbod)", ft = "dbout" },
    },
  },

  {
    "CopilotC-Nvim/CopilotChat.nvim",
    optional = true,
    opts = function()
      vim.api.nvim_create_autocmd("FileType", {
        group = augroup,
        pattern = "copilot-chat",
        callback = function(ev)
          vim.keymap.set("n", close_key, function()
            require("CopilotChat").close()
          end, { buffer = ev.buf, silent = true, desc = "Close (CopilotChat)" })
        end,
      })
    end,
  },

  {
    "yetone/avante.nvim",
    optional = true,
    opts = function()
      vim.api.nvim_create_autocmd("FileType", {
        group = augroup,
        pattern = { "Avante", "AvanteInput", "AvanteSelectedFiles", "AvanteSelectedCode" },
        callback = function(event)
          vim.keymap.set("n", close_key, function()
            require("avante").close_sidebar()
          end, { buffer = event.buf, silent = true, desc = "Close (Avante)" })
        end,
      })
    end,
  },

  {
    "olimorris/codecompanion.nvim",
    optional = true,
    opts = function()
      vim.api.nvim_create_autocmd("FileType", {
        group = augroup,
        pattern = "codecompanion",
        callback = function(event)
          -- -- close (clears chat history)
          -- vim.schedule(function()
          --   if not vim.api.nvim_buf_is_valid(event.buf) or U.is_floating_win(vim.fn.bufwinid(event.buf)) then
          --     -- floating window for copilot stats
          --     return
          --   end
          --
          --   local key = require("codecompanion.config").strategies.chat.keymaps.close.modes.n
          --   vim.keymap.set(
          --     "n",
          --     close_key,
          --     type(key) == "table" and key[1] or key,
          --     { buffer = event.buf, remap = true, silent = true, desc = "Close (CodeCompanion)" }
          --   )
          -- end)

          -- hide (does not clear chat history)
          vim.keymap.set(
            "n",
            close_key,
            "<cmd>close<cr>",
            { buffer = event.buf, silent = true, desc = "Close (CodeCompanion)" }
          )
        end,
      })
    end,
  },

  {
    "ThePrimeagen/harpoon",
    optional = true,
    keys = {
      {
        close_key,
        function()
          require("harpoon").ui:toggle_quick_menu()
        end,
        desc = "Close (Harpoon)",
        ft = "harpoon",
      },
    },
  },

  {
    "mfussenegger/nvim-jdtls",
    optional = true,
    opts = function()
      vim.api.nvim_create_autocmd("FileType", {
        group = augroup,
        pattern = "java",
        callback = function(event)
          if vim.startswith(vim.api.nvim_buf_get_name(event.buf), "jdt://") then
            vim.keymap.set("n", close_key, function()
              Snacks.bufdelete() -- `:bd` acts weirdly when neo-tree is visible
            end, { buffer = event.buf, desc = "Close (jdtls)" })
          end
        end,
      })
    end,
  },

  {
    "sindrets/diffview.nvim",
    optional = true,
    opts = function(_, opts)
      local actions = require("diffview.actions")
      LazyVim.extend(opts, "keymaps.view", { { "n", close_key, actions.close, { desc = "Close" } } })
      LazyVim.extend(opts, "keymaps.file_panel", { { "n", close_key, actions.close, { desc = "Close" } } })
      LazyVim.extend(
        opts,
        "keymaps.file_history_panel",
        { { "n", close_key, "<cmd>DiffviewClose<CR>", { desc = "Close" } } }
      )
    end,
  },

  {
    "NeogitOrg/neogit",
    optional = true,
    ---@module "neogit"
    ---@type NeogitConfig
    opts = {
      mappings = {
        commit_editor = {
          -- [close_key] = "Abort",
          [close_key] = "Close",
        },
        rebase_editor = {
          [close_key] = "Close",
        },
        status = {
          [close_key] = "Close",
        },
      },
    },
  },

  {
    "MagicDuck/grug-far.nvim",
    optional = true,
    opts = function()
      vim.api.nvim_create_autocmd("FileType", {
        group = augroup,
        pattern = "grug-far",
        callback = function(ev)
          vim.keymap.set("n", close_key, function()
            require("grug-far").get_instance(0):close()
          end, { buffer = ev.buf, desc = "Close (Grug Far)" })
        end,
      })
    end,
  },

  {
    "scalameta/nvim-metals",
    optional = true,
    opts = function()
      -- see: https://github.com/scalameta/nvim-metals/blob/df146792d5a642e92dd649b9130999d74e686e88/lua/metals/config.lua#L170-L200
      vim.api.nvim_create_autocmd("FileType", {
        group = augroup,
        pattern = "log",
        callback = function(ev)
          local buf = ev.buf
          vim.schedule(function()
            if
              vim.api.nvim_buf_is_valid(buf)
              and vim.bo[buf].buftype == "terminal"
              and vim.b[buf].metals_buf_purpose == "logs"
            then
              vim.keymap.set("n", close_key, function()
                if #vim.api.nvim_list_tabpages() > 1 then
                  vim.cmd("tabclose")
                end
                Snacks.bufdelete({ buf = buf })
              end, { buffer = buf, desc = "Close (Metals Logs)" })
            end
          end)
        end,
      })
    end,
  },

  {
    "mikesmithgh/kitty-scrollback.nvim",
    optional = true,
    opts = function()
      if vim.g.user_kitty_scrollback_nvim_minimal then
        return
      end

      local ksb_kitty_cmds = require("kitty-scrollback.kitty_commands")
      local ksb_api = require("kitty-scrollback.api")
      local plug = require("kitty-scrollback.util").plug_mapping_names

      vim.api.nvim_create_autocmd("FileType", {
        group = augroup,
        pattern = "kitty-scrollback",
        callback = function(ev)
          -- -- do not ask for saving changes for paste_window
          -- vim.keymap.set("n", close_key, plug.QUIT_ALL, { buffer = ev.buf, desc = "Force Quit" })
          -- if exit_key then
          --   vim.keymap.set("n", exit_key, plug.QUIT_ALL, { buffer = ev.buf, desc = "Force Quit All" })
          -- end

          vim.keymap.set("n", close_key, function()
            -- see: https://github.com/mikesmithgh/kitty-scrollback.nvim/blob/f6b982e3cdc2c45b00e0266c7c2d5a69c8bb5429/lua/kitty-scrollback/api.lua#L50
            if not pcall(ksb_kitty_cmds.send_paste_buffer_text_to_kitty_and_quit, false) then
              -- https://github.com/mikesmithgh/kitty-scrollback.nvim/blob/fea315d016eec41e807d67dd8980fa119850694a/lua/kitty-scrollback/kitty_commands.lua#L214: Invalid 'buffer': Expected Lua number
              ksb_api.quit_all()
            end
          end, { buffer = ev.buf, desc = "Quit and Paste" })
          if exit_key then
            vim.keymap.set("n", exit_key, close_key, { buffer = ev.buf, remap = true, desc = "Quit and Paste" })
          end
        end,
      })

      -- HACK: exit_key for pastebufs
      if exit_key then
        local mapped_pastebufs = {} ---@type table<integer, boolean>
        vim.api.nvim_create_autocmd("BufWinEnter", {
          group = augroup,
          callback = vim.schedule_wrap(function()
            local buf = vim.api.nvim_get_current_buf()
            if vim.api.nvim_buf_get_name(buf):match("%.ksb_pastebuf$") and not mapped_pastebufs[buf] then
              mapped_pastebufs[buf] = true
              vim.keymap.set("n", exit_key, plug.PASTE_CMD, { buffer = buf, desc = "Quit and Paste" })
            end
          end),
        })
      end
    end,
  },

  {
    "coder/claudecode.nvim",
    optional = true,
    opts = function()
      vim.api.nvim_create_autocmd("TabNewEntered", {
        group = augroup,
        callback = vim.schedule_wrap(function()
          local buf = vim.api.nvim_get_current_buf()
          if vim.b[buf].claudecode_diff_tab_name then
            vim.keymap.set("n", close_key, "<Cmd>ClaudeCodeDiffDeny<CR>", { buffer = buf, desc = "Deny Diff (Claude)" })
          end
        end),
      })
    end,
  },
}
