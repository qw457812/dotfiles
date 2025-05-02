return {
  {
    "copilotlsp-nvim/copilot-lsp",
    shell_command_editor = true,
    event = "LazyFile",
    keys = function(_, keys)
      local function nes_jump_or_apply()
        local nes = require("copilot-lsp.nes")
        return nes.walk_cursor_start_edit() or (nes.apply_pending_nes() and nes.walk_cursor_end_edit())
      end

      if vim.g.user_distinguish_ctrl_i_tab or vim.g.user_is_termux then
        table.insert(keys, {
          "<tab>",
          function()
            local _ = nes_jump_or_apply() or vim.cmd("wincmd w")
          end,
          desc = "Jump/Apply Suggestion or Next Window (Copilot LSP)",
        })
      end
    end,
    init = function()
      vim.g.copilot_nes_debounce = 500
      vim.lsp.enable("copilot_ls")
    end,
    specs = {
      { "zbirenbaum/copilot.lua", optional = true, enabled = false, cond = false },
      {
        "williamboman/mason.nvim",
        opts = { ensure_installed = { "copilot-language-server" } },
      },
      {
        "saghen/blink.cmp",
        optional = true,
        dependencies = {
          "fang2hou/blink-copilot",
          opts = function()
            U.toggle.ai_cmps.blink_copilot = Snacks.toggle({
              name = "Blink Copilot",
              get = function()
                return vim.g.user_blink_copilot ~= false
              end,
              set = function(state)
                vim.g.user_blink_copilot = state
              end,
            })
          end,
        },
        opts = {
          sources = {
            providers = {
              copilot = {
                enabled = function()
                  return vim.g.user_blink_copilot ~= false
                end,
              },
            },
          },
        },
      },
    },
  },

  {
    "nvim-lualine/lualine.nvim",
    optional = true,
    opts = function(_, opts)
      table.insert(
        opts.sections.lualine_x,
        2,
        LazyVim.lualine.status(LazyVim.config.icons.kinds.Copilot, function()
          local clients = package.loaded["copilot-lsp.nes"]
              and LazyVim.lsp.get_clients({ name = "copilot_ls", bufnr = 0 })
            or {}
          if #clients > 0 then
            return vim.b.nes_state and "pending" or "ok"
          end
        end)
      )
    end,
  },
}
