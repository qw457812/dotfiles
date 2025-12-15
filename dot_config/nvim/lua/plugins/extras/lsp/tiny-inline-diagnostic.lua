---@type LazySpec
return {
  {
    "rachartier/tiny-inline-diagnostic.nvim",
    -- priority = 1000,
    event = "VeryLazy",
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
        blend = {
          factor = vim.g.user_transparent_background and 0 or nil, -- same as `transparent_bg = vim.g.user_transparent_background`
        },
        -- transparent_bg = vim.g.user_transparent_background,
        options = {
          virt_texts = {
            priority = 5000, -- set higher than symbol-usage.nvim
          },
          use_icons_from_diagnostic = true,
          -- show_source = true,
          multilines = {
            enabled = true, -- not just current line
            -- always_show = true, -- show diagnostics on other lines even if cursor is on a diagnostic line
            severity = {
              vim.diagnostic.severity.ERROR,
            },
          },
          -- add_messages = {
          --   display_count = true, -- when `opts.options.multilines.enabled = true`
          --   -- show_multiple_glyphs = false, -- when `opts.options.multilines.enabled = true`
          -- },
          experimental = {
            use_window_local_extmarks = true,
          },
        },
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
              -- see: https://github.com/rachartier/tiny-inline-diagnostic.nvim/blob/e04c597bb11bad98413e8482fb46d21af66b7db7/lua/tiny-inline-diagnostic/state.lua#L44-L57
              if require("tiny-inline-diagnostic.state").user_toggle_state then
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
              -- only re-enable if it was previously enabled
              if not require("tiny-inline-diagnostic.state").user_toggle_state then
                require("tiny-inline-diagnostic").enable()
              end
            end,
          })
        end,
      },
    },
  },
}
