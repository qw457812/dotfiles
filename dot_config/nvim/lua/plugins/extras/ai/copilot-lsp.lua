-- TODO: https://github.com/neovim/nvim-lspconfig/pull/4029#issuecomment-3218682706
return {
  {
    "copilotlsp-nvim/copilot-lsp",
    shell_command_editor = true,
    event = "LazyFile",
    keys = function(_, keys)
      ---@return boolean
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

      U.toggle.ai_cmps.copilot_lsp = Snacks.toggle({
        name = "Copilot LSP",
        get = function()
          return vim.lsp.is_enabled("copilot_ls")
        end,
        set = function(state)
          vim.lsp.enable("copilot_ls", state)
        end,
      })
    end,
    ---@module "copilot-lsp"
    ---@type copilotlsp.config|{}
    opts = {},
    specs = {
      { "zbirenbaum/copilot.lua", optional = true, enabled = false, cond = false },
      {
        "mason-org/mason.nvim",
        opts = { ensure_installed = { "copilot-language-server" } },
      },
      -- update blink menu position when copilot NES is visible
      -- see: https://github.com/Saghen/blink.cmp/issues/1801#issuecomment-2956456623
      {
        "saghen/blink.cmp",
        optional = true,
        opts = function(_, opts)
          vim.api.nvim_create_autocmd("User", {
            pattern = "BlinkCmpMenuOpen",
            callback = function()
              local timer = assert(vim.uv.new_timer())
              local last_nes_visible = vim.b.nes_state ~= nil

              timer:start(
                0,
                80,
                vim.schedule_wrap(function()
                  local nes_visible = vim.b.nes_state ~= nil
                  if nes_visible ~= last_nes_visible then
                    last_nes_visible = nes_visible
                    require("blink.cmp.completion.windows.menu").update_position()
                    -- see: https://github.com/saghen/blink.cmp/blob/a026b8db7f8ab0e98b9a2e0a7a8d7a7b73410a27/lua/blink/cmp/signature/window.lua#L123-L131
                    -- copied from: https://github.com/saghen/blink.cmp/blob/a5be099b0519339bc0d9e2dc96744b55640e810e/lua/blink/cmp/init.lua#L279-L284
                    if nes_visible and require("blink.cmp").is_signature_visible() then
                      require("blinn.cmp.signature.trigger").hide()
                    end
                  end
                end)
              )

              -- clean up timer when menu closes
              vim.api.nvim_create_autocmd("User", {
                pattern = "BlinkCmpMenuClose",
                once = true,
                callback = function()
                  timer:stop()
                  if not timer:is_closing() then
                    timer:close()
                  end
                end,
              })
            end,
          })

          return U.extend_tbl(opts, {
            ---@module "blink.cmp"
            ---@type blink.cmp.CompletionConfigPartial
            completion = {
              menu = {
                direction_priority = function()
                  return vim.b.nes_state and { "n", "s" } or { "s", "n" }
                end,
              },
            },
          })
        end,
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
          local clients = package.loaded["copilot-lsp"] and LazyVim.lsp.get_clients({ name = "copilot_ls", bufnr = 0 })
            or {}
          if #clients > 0 then
            return vim.b.nes_state and "pending" or "ok"
          end
        end)
      )
    end,
  },
}
