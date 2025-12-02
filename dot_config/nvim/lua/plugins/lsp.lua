---@type LazySpec
return {
  {
    "neovim/nvim-lspconfig",
    ---@param opts PluginLspOpts
    opts = function(_, opts)
      -- opts.folds.enabled
      Snacks.util.lsp.on({ method = "textDocument/foldingRange" }, function(buf)
        local fname = vim.api.nvim_buf_get_name(buf)
        if vim.o.diff or fname:match("/%.metals/readonly/dependencies/") then -- TODO: check if https://github.com/neovim/neovim/pull/36708 fixes metals
          return
        end
        if LazyVim.set_default("foldmethod", "expr") then
          LazyVim.set_default("foldexpr", "v:lua.vim.lsp.foldexpr()")
        end
      end)

      local has_tiny_diag = LazyVim.has("tiny-inline-diagnostic.nvim")
      return U.extend_tbl(opts, {
        folds = { enabled = false }, -- set up on our own above
        ---@type vim.diagnostic.Opts
        diagnostics = {
          -- signs = {
          --   priority = 9999,
          --   severity = {
          --     min = vim.diagnostic.severity.WARN,
          --     max = vim.diagnostic.severity.ERROR,
          --   },
          -- },
          -- underline = {
          --   severity = {
          --     min = vim.diagnostic.severity.HINT,
          --     max = vim.diagnostic.severity.ERROR,
          --   },
          -- },
          virtual_text = not has_tiny_diag and {
            prefix = "icons",
            current_line = true,
            -- severity = {
            --   min = vim.diagnostic.severity.ERROR,
            --   max = vim.diagnostic.severity.ERROR,
            -- },
          } --[[@as vim.diagnostic.Opts.VirtualText]],
        },
      } --[[@as PluginLspOpts]])
    end,
  },
  {
    "neovim/nvim-lspconfig",
    ---@type PluginLspOpts
    opts = {
      ---@type table<string, lazyvim.lsp.Config|boolean>
      servers = {
        ["*"] = {
          -- stylua: ignore
          keys = {
            { "K", false },
            {
              "gk",
              function() return vim.lsp.buf.hover() end,
              desc = "Hover",
              has = "hover", -- add `has = "hover"` to prevent rime_ls from overwriting `gk` in help pages
              enabled = function() return not LazyVim.has("nvim-ufo") end,
            },
            { "<c-k>", mode = "i", false }, -- <c-k> for cmp navigation
            { "<c-h>", function() return vim.lsp.buf.signature_help() end, mode = "i", desc = "Signature Help", has = "signatureHelp" }, -- can conflict with mini.snippets
            {
              "<cr>",
              U.lsp.pick_definitions_or_references,
              desc = "Goto Definition/References",
              has = "definition",
              enabled = function()
                if LazyVim.has("sidekick.nvim") then
                  return false
                end
                if vim.bo.filetype == "markdown" then
                  -- for gaoDean/autolist.nvim
                  return false
                end
                -- check to see if `<cr>` is already mapped to the buffer (avoids overwriting)
                -- for yarospace/lua-console.nvim
                return not U.keymap.exists("n", "<cr>", { buf = true })
              end,
            },
            -- https://zed.dev/docs/vim#language-server
            { "cd", "<leader>cr", desc = "Rename (change definition)", has = "rename", remap = true },
            { "gs", "<leader>ss", desc = "LSP Symbols", has = "documentSymbol", remap = true },
            { "gS", "<leader>sS", desc = "LSP Workspace Symbols", has = "workspace/symbols", remap = true },
            { "<leader>cl", false },
            -- { "<leader>il", "<cmd>LspInfo<cr>", desc = "Lsp" },
            { "<leader>il", function() Snacks.picker.lsp_config() end, desc = "Lsp" },
            { "<leader>clr", "<cmd>LspRestart<cr>", desc = "Restart Lsp" },
            { "<leader>cls", "<cmd>LspStart<cr>", desc = "Start Lsp" },
            { "<leader>clS", "<cmd>LspStop<cr>", desc = "Stop Lsp" },
            { "<leader>clW", function() vim.lsp.buf.remove_workspace_folder() end, desc = "Remove Workspace" },
            { "<leader>clw", function() vim.lsp.buf.add_workspace_folder() end, desc = "Add Workspace" },
            {
              "<leader>clL",
              function()
                LazyVim.info(vim.tbl_map(U.path.home_to_tilde, vim.lsp.buf.list_workspace_folders()), { title = "Lsp Workspaces" })
              end,
              desc = "List Workspace",
            },
          },
        },
      },
    },
  },
  LazyVim.pick.picker.name == "snacks"
      and {
        "neovim/nvim-lspconfig",
        opts = {
          ---@type table<string, lazyvim.lsp.Config|boolean>
          servers = {
            ["*"] = {
              keys = {
                {
                  "<leader>ss",
                  function()
                    -- see: https://github.com/folke/snacks.nvim/issues/1057#issuecomment-2652052218
                    -- copied from: https://github.com/disrupted/dotfiles/blob/60e5eff02e2f4aff30dae259cdebdfe172b8e6fe/.config/nvim/lua/plugins/plugins.lua#L181-L253
                    local cursor = vim.api.nvim_win_get_cursor(0)
                    local picker = Snacks.picker.lsp_symbols({ filter = LazyVim.config.kind_filter })
                    -- focus the symbol at the cursor position
                    picker.matcher.task:on(
                      "done",
                      vim.schedule_wrap(function()
                        for symbol in vim.iter(picker:items()):rev() do
                          if U.lsp.cursor_in_range(cursor, symbol.range) then
                            picker.list:move(symbol.idx, true)
                            return
                          end
                        end
                      end)
                    )
                  end,
                  desc = "LSP Symbols",
                  has = "documentSymbol",
                },
              },
            },
          },
        },
      }
    or { import = "foobar", enabled = false },
  {
    "folke/which-key.nvim",
    opts = {
      spec = {
        { "<leader>cl", group = "Lsp", icon = { icon = " ", color = "purple" } },
      },
    },
  },
  {
    "LazyVim/LazyVim",
    opts = function()
      vim.api.nvim_create_autocmd("FileType", {
        pattern = { "help", "man", "checkhealth" },
        callback = function(ev)
          vim.keymap.set("n", "gs", "gO", { buffer = ev.buf, silent = true, remap = true, desc = "Show Outline" })
        end,
      })
    end,
  },

  {
    "saecki/live-rename.nvim",
    lazy = true,
    specs = {
      {
        "neovim/nvim-lspconfig",
        opts = {
          ---@type table<string, lazyvim.lsp.Config|boolean>
          servers = {
            ["*"] = {
              keys = {
                {
                  "<leader>cr",
                  function()
                    local live_rename = require("live-rename")
                    live_rename.rename()

                    local buf = vim.api.nvim_get_current_buf()
                    -- see: https://github.com/saecki/live-rename.nvim/blob/78fcdb4072c6b1a8e909872f9a971b2f2b642d1e/lua/live-rename.lua#L467
                    if vim.fn.fnamemodify(vim.api.nvim_buf_get_name(buf), ":t") == "lsp:rename" then
                      vim.b[buf].completion = false -- disable blink.cmp in favor of <cr>
                      vim.keymap.set(
                        { "n", "i" },
                        "<C-s>",
                        live_rename.submit,
                        { buffer = buf, desc = "Submit rename" }
                      )
                      vim.keymap.set("n", "<C-c>", live_rename.hide, { buffer = buf, desc = "Cancel rename" })
                      vim.keymap.set("i", "<C-c>", function()
                        vim.cmd("stopinsert")
                        live_rename.hide()
                      end, { buffer = buf, desc = "Cancel rename" })
                    end
                  end,
                  desc = "Rename (live-rename.nvim)",
                  has = "rename",
                },
              },
            },
          },
        },
      },
    },
  },

  {
    "folke/snacks.nvim",
    ---@type snacks.Config
    opts = {
      picker = {
        sources = {
          lsp_symbols = {
            confirm = function(picker, item, action)
              -- HACK: fix the error occurring in the jdtls class buffer when neo-tree is open:
              -- vim.schedule callback: https://github.com/folke/snacks.nvim/blob/3d695ab7d062d40c980ca5fd9fe6e593c8f35b12/lua/snacks/picker/actions.lua#L128: Cursor position outside buffer
              -- see: https://github.com/folke/snacks.nvim/commit/4551f499c7945036761fd48927cc07b9720fce56
              -- local main = require("snacks.picker.core.main").new({ float = false, file = false })
              -- vim.api.nvim_set_current_win(main:get())
              -- see: https://github.com/folke/snacks.nvim/commit/85b8ec210975aa137af4b7bef1fb7b7098be331a
              picker.main = picker:filter().current_win

              -- original confirm action
              Snacks.picker.actions.confirm(picker, item, action)
            end,
          },
        },
      },
    },
  },

  {
    "mason-org/mason.nvim",
    optional = true,
    ---@module "mason"
    ---@type MasonSettings
    opts = {
      ui = {
        width = vim.g.user_is_termux and 1 or nil,
        height = vim.g.user_is_termux and vim.o.lines - 4 or nil, -- see: U.snacks.win.fullscreen_height
        keymaps = {
          uninstall_package = "x",
          apply_language_filter = "f",
          toggle_help = "?",
        },
      },
    },
  },

  {
    "folke/noice.nvim",
    optional = true,
    opts = function(_, opts)
      opts.routes = opts.routes or {}
      -- https://github.com/folke/noice.nvim/wiki/Configuration-Recipes#ignore-certain-lsp-servers-for-progress-messages
      table.insert(opts.routes, {
        filter = {
          event = "lsp",
          kind = "progress",
          cond = function(message)
            -- dd(vim.tbl_get(message.opts, "progress"))
            return vim.g.user_suppress_lsp_progress == true
          end,
        },
        opts = { skip = true },
      })
      table.insert(opts.routes, {
        filter = {
          event = "notify",
          find = "^No information available$", -- hover by `K`
        },
        view = "mini",
      })
    end,
  },

  {
    "folke/noice.nvim",
    optional = true,
    opts = function(_, opts)
      -- https://github.com/chrisgrieser/nvim-origami/blob/7e38cff819414471de8fbfbb48ccde06dcf966fb/lua/origami/features/autofold-comments-imports.lua#L27
      -- https://github.com/neovim/neovim/blob/1c417b565ec82839aee12918eb8b3e93b91cc253/runtime/lua/vim/lsp/_folding_range.lua
      -- TODO: check if https://github.com/neovim/neovim/pull/36708 fixes these errors
      table.insert(opts.routes, {
        filter = {
          event = "msg_show",
          any = {
            {
              find = "vim%.schedule.*callback: .+/runtime/lua/vim/lsp/_folding_range%.lua:%d+: attempt to index a nil value",
            },
            {
              find = "vim%.schedule.*callback: .+/runtime/lua/vim/lsp/_folding_range%.lua:%d+: assertion failed!",
            },
            {
              find = "vim%.schedule.*callback: .+/runtime/lua/vim/lsp/_folding_range%.lua:%d+: Invalid window id: %d+",
            },
          },
        },
        opts = { skip = true },
      })
    end,
  },
}
