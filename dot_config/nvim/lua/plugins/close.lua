local close_key, exit_key, term_close_key = vim.g.user_close_key, vim.g.user_exit_key, vim.g.user_term_close_key
if not close_key then
  vim.notify("`vim.g.user_close_key` is required", "warn", { title = "Close" })
  return {}
end

-- TODO: find a key to close window(/buffer or exit)

-- do not use `clear = true` at the top-level, it will be triggered by lazy.nvim on `Config Change Detected. Reloading...`
local augroup = vim.api.nvim_create_augroup("close_with_" .. close_key, { clear = false })

-- alternative to psjay/buffer-closer.nvim
-- copied from: https://github.com/psjay/buffer-closer.nvim/blob/74fec63c4c238b2cf6f61c40b47f869d442a8988/lua/buffer-closer/init.lua#L10
-- https://github.com/chrisgrieser/.config/blob/88eb71f88528f1b5a20b66fd3dfc1f7bd42b408a/nvim/lua/funcs/alt-alt.lua#L42
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

  -- https://github.com/AstroNvim/AstroNvim/blob/d771094986abced8c3ceae29a5a55585ecb0523a/lua/astronvim/plugins/_astrocore_autocmds.lua#L245
  -- https://github.com/nvim-neo-tree/neo-tree.nvim/blob/42caaf5c3b7ca346ab278201151bb878006a6031/lua/neo-tree/utils/init.lua#L533
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
  -- https://github.com/mudox/neovim-config/blob/a4f1020213fd17e6b8c1804153b9bf7683bfa690/lua/mudox/lab/close.lua#L7
  if U.is_floating_win() then
    vim.cmd("close") -- Close Window (Cannot close last window)
  elseif #listed_buffers() > (vim.bo.buflisted and 1 or 0) then
    if non_real_file() or is_winfixbuf() then
      vim.cmd("bd") -- Delete Buffer and Window
    else
      Snacks.bufdelete() -- Delete Buffer
    end
  else
    vim.cmd("qa")
  end
end

return {
  {
    "LazyVim/LazyVim",
    keys = function(_, keys)
      vim.list_extend(keys, {
        { close_key, close_buffer_or_window_or_exit, desc = "Close buffer/window or Exit" },
        { close_key, mode = "x", "<esc>", desc = "Stop Visual Mode" },
      })
      if exit_key then
        table.insert(keys, { exit_key, "<cmd>qa<cr>", desc = "Quit All" })
      end
      if term_close_key then
        vim.list_extend(keys, {
          { term_close_key, mode = "t", "<cmd>bd!<cr>", desc = "Close terminal" }, -- <cmd>close<cr>
          { term_close_key, close_key, desc = "Close buffer/window or Exit", remap = true },
        })
      end
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
              -- see: https://github.com/echasnovski/mini.pairs/blob/7e834c5937d95364cc1740e20d673afe2d034cdb/lua/mini/pairs.lua#L574C5-L576C54
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

      -- see `:h q:`
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
                  desc = "Quit buffer",
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
          -- clear_ui_or_close = {
          --   "<esc>",
          --   function(self)
          --     U.keymap.clear_ui_esc({
          --       -- close = function() self:close() end,
          --       esc = false,
          --     })
          --   end,
          --   desc = "Clear UI or Close",
          -- },
        },
      },
      -- override the opts.win.keys to avoid exiting terminal
      terminal = {
        win = {
          keys = {
            [close_key] = "hide",
            -- -- use the same `clear_ui_or_close` key to ensure overwriting
            -- clear_ui_or_close = {
            --   "<esc>",
            --   function(self)
            --     U.keymap.clear_ui_esc({
            --       -- close = function() self:hide() end,
            --       esc = false,
            --     })
            --   end,
            --   desc = "Clear UI or Close",
            -- },
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
              [close_key] = "close",
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
    "nvim-neo-tree/neo-tree.nvim",
    optional = true,
    opts = {
      window = {
        mappings = {
          [close_key] = "close_window",
        },
      },
    },
  },
  {
    "nvim-neo-tree/neo-tree.nvim",
    optional = true,
    opts = function()
      vim.api.nvim_create_autocmd("FileType", {
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
    "echasnovski/mini.files",
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
    "yetone/avante.nvim",
    optional = true,
    opts = function(_, opts)
      local defaults = require("avante.config")._defaults

      vim.api.nvim_create_autocmd("FileType", {
        group = augroup,
        pattern = {
          -- "Avante",
          "AvanteInput",
          "AvanteSelectedFiles",
        },
        callback = function(event)
          vim.keymap.set("n", close_key, "<cmd>close<cr>", {
            buffer = event.buf,
            silent = true,
            desc = "Quit buffer",
          })
        end,
      })

      return U.extend_tbl(opts, {
        mappings = {
          sidebar = {
            close = vim.list_extend(
              vim.tbl_get(opts, "mappings", "sidebar", "close") or vim.deepcopy(defaults.mappings.sidebar.close),
              { close_key }
            ),
          },
        },
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
}
