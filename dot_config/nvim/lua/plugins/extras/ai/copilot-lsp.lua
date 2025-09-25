-- vim.g.ai_cmp = false

if not (vim.g.ai_cmp or vim.lsp.inline_completion) then
  LazyVim.error("You need Neovim >= 0.12 or `vim.g.ai_cmp` enabled to use the `ai.copilot-lsp` user extra.")
  return {}
end
if LazyVim.has_extra("ai.copilot") then
  LazyVim.error("Please disable the `ai.copilot` extra if you want to use `ai.copilot-lsp`")
  return {}
end

local status = {} ---@type table<number, "ok" | "error" | "pending">

---@type LazySpec
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
      return keys
    end,
    init = function()
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
      {
        "neovim/nvim-lspconfig",
        opts = {
          ---@type table<string, vim.lsp.Config>
          servers = {
            copilot_ls = {
              root_dir = function(bufnr, on_dir)
                -- on_dir(vim.fs.root(bufnr, vim.lsp.config.copilot.root_markers))
                on_dir(LazyVim.root.get({ normalize = true, buf = bufnr }))
              end,
              handlers = {
                didChangeStatus = function(err, res, ctx)
                  require("copilot-lsp.handlers").didChangeStatus(err, res, ctx)
                  if not err then
                    status[ctx.client_id] = res.kind ~= "Normal" and "error" or res.busy and "pending" or "ok"
                  end
                end,
              },
              -- stylua: ignore
              keys = vim.g.ai_cmp and {} or {
                {
                  "<M-]>",
                  function() vim.lsp.inline_completion.select({ count = 1 }) end,
                  desc = "Next Copilot LSP Suggestion",
                  mode = { "i", "n" },
                },
                {
                  "<M-[>",
                  function() vim.lsp.inline_completion.select({ count = -1 }) end,
                  desc = "Next Copilot LSP Suggestion",
                  mode = { "i", "n" },
                },
              },
            },
          },
          setup = {
            copilot_ls = function()
              vim.g.copilot_nes_debounce = 500

              if vim.g.ai_cmp then
                return
              end
              vim.lsp.inline_completion.enable()
              ---@diagnostic disable-next-line: duplicate-set-field
              LazyVim.cmp.actions.ai_accept = function()
                return vim.lsp.inline_completion.get()
              end
            end,
          },
        },
      },
      -- with the way LazyVim sets up mason-lspconfig.nvim, using opts.ensure_installed of mason.nvim will automatically enable installed servers
      -- see: https://github.com/LazyVim/LazyVim/blob/8a760984611cd9df0971a9f36a94838b9e32453f/lua/lazyvim/plugins/lsp/init.lua#L217-L220
      {
        "neovim/nvim-lspconfig",
        opts = {
          -- ensure mason installs copilot-language-server
          servers = {
            copilot = {},
          },
          setup = {
            copilot = function()
              return true -- but don't automatically enable it since we already enabled copilot_ls
            end,
          },
        },
      },
    },
  },

  -- update blink menu position when copilot NES is visible
  -- see: https://github.com/Saghen/blink.cmp/issues/1801#issuecomment-2956456623
  -- TODO: update blink menu position when copilot inline_completion is visible (via `status`)
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
                  require("blink.cmp.signature.trigger").hide()
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

  {
    "nvim-lualine/lualine.nvim",
    optional = true,
    opts = function(_, opts)
      table.insert(
        opts.sections.lualine_x,
        2,
        LazyVim.lualine.status(LazyVim.config.icons.kinds.Copilot, function()
          local clients = package.loaded["copilot-lsp"] and vim.lsp.get_clients({ name = "copilot_ls", bufnr = 0 })
            or {}
          if #clients > 0 then
            return vim.b.nes_state and "pending" or status[clients[1].id]
          end
        end)
      )
    end,
  },

  vim.g.ai_cmp and {
    "saghen/blink.cmp",
    optional = true,
    dependencies = { "fang2hou/blink-copilot" },
    opts = {
      sources = {
        default = { "copilot" },
        providers = {
          copilot = {
            name = "copilot",
            module = "blink-copilot",
            score_offset = 100,
            async = true,
          },
        },
      },
    },
  } or nil,
}
