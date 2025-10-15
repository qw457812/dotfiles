---@type LazySpec
return {
  -- https://github.com/search?q=repo%3Aaimuzov%2FLazyVimx%20tiny-inline-diagnostic.nvim&type=code
  {
    "rachartier/tiny-inline-diagnostic.nvim",
    -- priority = 1000,
    -- lazy = false,
    event = "VeryLazy", -- LspAttach
    opts_extend = { "disabled_ft" },
    opts = function()
      local orig_open_float = vim.diagnostic.open_float
      local tiny_diag_open_float = require("tiny-inline-diagnostic.override").open_float
      ---@diagnostic disable-next-line: duplicate-set-field
      vim.diagnostic.open_float = function(...)
        if U.toggle.is_diagnostic_virt_enabled == false then
          return orig_open_float(...)
        else
          return tiny_diag_open_float(...)
        end
      end

      return {
        signs = {
          left = " ",
          right = " ",
          arrow = "  ",
          up_arrow = "  ",
        },
        options = {
          virt_texts = { priority = 5000 }, -- set higher than symbol-usage.nvim
          use_icons_from_diagnostic = true,
          -- multilines = true, -- not just current line
          -- show_source = true,
        },
        -- blend = { factor = vim.g.user_transparent_background and 0 or nil },
      }
    end,
    specs = {
      {
        "folke/sidekick.nvim",
        optional = true,
        opts = function()
          vim.api.nvim_create_autocmd("User", {
            pattern = "SidekickNesShow",
            callback = function()
              if U.toggle.is_diagnostic_virt_enabled == false then
                return
              end
              -- see: https://github.com/rachartier/tiny-inline-diagnostic.nvim/blob/9d5b02aea0f53926db5967eb753b0a15defe99be/lua/tiny-inline-diagnostic/diagnostic.lua#L449-L462
              if require("tiny-inline-diagnostic.diagnostic").user_toggle_state then
                require("tiny-inline-diagnostic").disable()
              end
            end,
          })

          vim.api.nvim_create_autocmd("User", {
            pattern = "SidekickNesHide",
            callback = function()
              if U.toggle.is_diagnostic_virt_enabled == false then
                return
              end
              if not require("tiny-inline-diagnostic.diagnostic").user_toggle_state then
                require("tiny-inline-diagnostic").enable()
              end
            end,
          })
        end,
      },
    },
  },
}
