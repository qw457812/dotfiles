if LazyVim.has_extra("ai.copilot-lsp") then
  if LazyVim.has_extra("ai.copilot") then
    LazyVim.error("Please disable the `ai.copilot` extra if you want to use `ai.copilot-lsp`")
    return {}
  end
  if LazyVim.has_extra("ai.copilot-native") then
    LazyVim.error("Please disable the `ai.copilot-native` extra if you want to use `ai.copilot-lsp`")
    return {}
  end
  if LazyVim.has_extra("ai.sidekick") then
    LazyVim.error("Please disable the `ai.sidekick` extra if you want to use `ai.copilot-lsp`")
    return {}
  end

  if not vim.lsp.inline_completion then
    if not LazyVim.has_extra("coding.blink") then
      LazyVim.error("You need Neovim >= 0.12 or `coding.blink` extra to use the `ai.copilot-lsp` extra.")
      return {}
    end
    vim.g.ai_cmp = true
  end
end

local status = {} ---@type table<number, "ok" | "error" | "pending">

-- https://github.com/LazyVim/LazyVim/blob/c83df9e68dd41f5a3f7df5a7048169ee286a7da8/lua/lazyvim/plugins/extras/ai/copilot-native.lua
---@type LazySpec
return {
  {
    "copilotlsp-nvim/copilot-lsp",
    shell_command_editor = true,
    event = "LazyFile",
    keys = function(_, keys)
      if vim.g.user_distinguish_ctrl_i_tab or vim.g.user_is_termux then
        table.insert(keys, {
          "<tab>",
          LazyVim.cmp.map({ "ai_accept" }, function()
            vim.cmd("wincmd w")
          end),
          desc = "Jump/Apply Next Edit Suggestions or Next Window (Copilot LSP)",
        })
      end
      return keys
    end,
    opts = function()
      U.toggle.ai_cmps.copilot_lsp = Snacks.toggle({
        name = "copilot-lsp",
        get = function()
          return vim.lsp.is_enabled("copilot_ls")
        end,
        set = function(state)
          vim.lsp.enable("copilot_ls", state)
        end,
      })
    end,
    specs = {
      {
        "neovim/nvim-lspconfig",
        opts = {
          ---@type table<string, vim.lsp.Config>
          servers = {
            copilot_ls = {
              root_dir = function(bufnr, on_dir)
                local root = LazyVim.root({ buf = bufnr })
                on_dir(root ~= vim.uv.cwd() and root or vim.fs.root(bufnr, vim.lsp.config.copilot.root_markers))
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

              if not vim.g.ai_cmp then
                -- TODO: https://github.com/neovim/nvim-lspconfig/commit/5b1a75b
                vim.schedule(function()
                  vim.lsp.inline_completion.enable()
                end)
              end

              -- HACK: `vim.g.ai_cmp` changed to false after `:LazyExtras` even when `ai.copilot-native` is not enabled
              -- caused by: https://github.com/LazyVim/LazyVim/blob/ed637bb0f7f418de069a4d5a7ed8a7b3b93eb425/lua/lazyvim/plugins/extras/ai/copilot-native.lua#L18
              local ai_cmp = vim.g.ai_cmp
              -- Accept inline completion or next edit suggestions
              ---@diagnostic disable-next-line: duplicate-set-field
              LazyVim.cmp.actions.ai_accept = function()
                -- prefer inline completion if available
                if not ai_cmp and vim.lsp.inline_completion.get() then
                  return true
                end

                -- otherwise, try to jump to or apply nes
                if package.loaded["copilot-lsp.nes"] and vim.b.nes_state then
                  local nes = require("copilot-lsp.nes")
                  if nes.walk_cursor_start_edit() or (nes.apply_pending_nes() and nes.walk_cursor_end_edit()) then
                    vim.cmd("stopinsert")
                    return true
                  end
                end
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
  -- TODO: disable nes in insert mode
  -- ref: https://github.com/LazyVim/LazyVim/blob/c83df9e68dd41f5a3f7df5a7048169ee286a7da8/lua/lazyvim/plugins/extras/ai/copilot-native.lua#L64-L75
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
              Snacks.util.stop(timer)
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
    dependencies = "fang2hou/blink-copilot",
    opts = {
      sources = {
        default = { "copilot" },
        providers = {
          copilot = {
            module = "blink-copilot",
            score_offset = 100,
            async = true,
          },
        },
      },
    },
  } or nil,
}
