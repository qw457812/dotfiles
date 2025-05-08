-- https://github.com/olimorris/dotfiles/blob/07ac630debbbb78a638413381736a8860647e537/.config/nvim/lua/plugins/coding.lua
return {
  {
    "olimorris/codecompanion.nvim",
    dependencies = {
      -- {
      --   "Davidyz/VectorCode",
      --   version = "*",
      --   build = "pipx upgrade vectorcode",
      -- },
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
                default = "claude-3.7-sonnet",
              },
            },
          })
        end,
      },
      strategies = {
        chat = {
          adapter = "copilot",
          -- tools = {
          --   vectorcode = {
          --     description = "Run VectorCode to retrieve the project context.",
          --     callback = function()
          --       return require("vectorcode.integrations").codecompanion.chat.make_tool()
          --     end,
          --   },
          -- },
        },
        inline = { adapter = "copilot" },
      },
      display = {
        action_palette = {
          provider = ({ snacks = "snacks", telescope = "telescope" })[LazyVim.pick.picker.name],
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
          vim.keymap.set("n", "<Esc>", function()
            if not U.keymap.clear_ui_esc() then
              vim.cmd.wincmd("p")
            end
          end, { buffer = buf, desc = "Clear UI or Unfocus (CodeCompanion)" })

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
    end,
  },

  -- TODO: https://github.com/ravitemer/codecompanion-history.nvim
}
