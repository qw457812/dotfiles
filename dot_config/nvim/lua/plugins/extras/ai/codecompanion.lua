-- https://github.com/olimorris/dotfiles/blob/8b81a8acdc8135355c15c3f6ca351c1524a55d17/.config/nvim/lua/plugins/coding.lua
return {
  {
    "olimorris/codecompanion.nvim",
    dependencies = {
      {
        "MeanderingProgrammer/render-markdown.nvim",
        optional = true,
        ft = U.markdown.render_markdown_ft("codecompanion"),
      },
    },
    cmd = { "CodeCompanion" },
    keys = {
      {
        "<leader>al",
        -- "<cmd>CodeCompanionChat Toggle<CR>",
        function()
          -- https://github.com/olimorris/codecompanion.nvim/blob/3f7fd6292b9d43d38e9760f43b581652210b0349/lua/codecompanion/init.lua#L178-L192
          local codecompanion = require("codecompanion")
          local chat = codecompanion.last_chat()
          if chat and chat.ui:is_visible() then
            vim.api.nvim_set_current_win(chat.ui.winnr)
            U.stop_visual_mode()
            vim.cmd("startinsert!")
          else
            codecompanion.toggle()
          end
        end,
        desc = "CodeCompanion",
        mode = { "n", "x" },
      },
      {
        "<leader>aop",
        "<cmd>CodeCompanionActions<CR>",
        desc = "Actions (CodeCompanion)",
        mode = { "n", "x" },
      },
      {
        "<leader>aoa",
        "<cmd>CodeCompanionChat Add<CR>",
        desc = "Add (CodeCompanion)",
        mode = { "n", "x" },
      },
    },
    opts = {
      adapters = {
        copilot = function()
          return require("codecompanion.adapters").extend("copilot", {
            schema = {
              model = {
                -- default = "claude-3.7-sonnet",
                default = "gemini-2.5-pro",
              },
            },
          })
        end,
      },
      strategies = {
        chat = {
          adapter = "copilot",
        },
        inline = {
          adapter = "copilot",
        },
      },
      display = {
        action_palette = {
          provider = "default",
        },
        chat = {
          -- show_settings = true,
          start_in_insert_mode = true,
          window = {
            layout = vim.o.columns >= 120 and "vertical" or "horizontal",
            height = 0.5,
            width = 0.4,
          },
        },
        diff = {
          provider = "mini_diff",
        },
      },
    },
  },
  {
    "folke/which-key.nvim",
    opts = {
      spec = {
        { "<leader>ao", group = "codecompanion" },
      },
    },
  },
  {
    "olimorris/codecompanion.nvim",
    optional = true,
    opts = function()
      local augroup = vim.api.nvim_create_augroup("codecompanion_keymaps", { clear = true })
      vim.api.nvim_create_autocmd("FileType", {
        group = augroup,
        pattern = "codecompanion",
        callback = function(ev)
          local buf = ev.buf
          vim.b[buf].user_blink_path = false

          vim.keymap.set(
            "n",
            "<Esc>",
            U.keymap.clear_ui_or_unfocus_esc,
            { buffer = buf, desc = "Clear UI or Unfocus (CodeCompanion)" }
          )

          vim.api.nvim_create_autocmd("BufLeave", {
            group = augroup,
            buffer = buf,
            callback = function()
              -- for i_<C-c>
              vim.cmd("stopinsert")
            end,
          })
        end,
      })

      -- HACK: stop insert mode on send via `i_CTRL-S`
      -- https://github.com/olimorris/codecompanion.nvim/blob/90e82abf4d65b64b0986a5be0981ba13e84eee8b/lua/codecompanion/strategies/chat/keymaps.lua#L214-L218
      local chat_keymaps = require("codecompanion.strategies.chat.keymaps")
      chat_keymaps.send.callback = U.patch_func(chat_keymaps.send.callback, function(orig, ...)
        orig(...)
        vim.cmd("stopinsert")
      end)
    end,
  },

  -- vim.fn.executable("vectorcode") == 1 and {
  --   "olimorris/codecompanion.nvim",
  --   dependencies = {
  --     {
  --       "Davidyz/VectorCode",
  --       version = "*",
  --       build = "pipx upgrade vectorcode",
  --       cmd = "VectorCode",
  --     },
  --   },
  --   opts = {
  --     extensions = {
  --       vectorcode = {
  --         opts = {
  --           add_tool = true,
  --         },
  --       },
  --     },
  --   },
  -- } or nil,

  -- TODO: https://github.com/ravitemer/codecompanion-history.nvim
}
