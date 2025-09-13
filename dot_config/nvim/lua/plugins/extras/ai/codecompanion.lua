-- https://github.com/olimorris/dotfiles/blob/459dfcc8f2952f80c428353cc9c3fc2d90cbcf8d/.config/nvim/lua/plugins/coding.lua
-- https://github.com/petobens/dotfiles/blob/08ae687d7c8b9669af1278ef44bfaaf1f6e6f957/nvim/lua/plugin-config/codecompanion_config.lua
---@type LazySpec
return {
  {
    "olimorris/codecompanion.nvim",
    cmd = "CodeCompanion",
    keys = {
      {
        "<leader>ann",
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
        "<leader>anp",
        "<cmd>CodeCompanionActions<CR>",
        desc = "Actions (CodeCompanion)",
        mode = { "n", "x" },
      },
      {
        "<leader>ana",
        "<cmd>CodeCompanionChat Add<CR>",
        desc = "Add (CodeCompanion)",
        mode = { "n", "x" },
      },
    },
    opts = {
      adapters = {
        -- copilot = function()
        --   return require("codecompanion.adapters").extend("copilot", {
        --     schema = {
        --       model = {
        --         default = "gemini-2.5-pro", -- claude-sonnet-4
        --       },
        --     },
        --   })
        -- end,
        acp = {
          claude_code = function()
            return require("codecompanion.adapters").extend("claude_code", {
              env = {
                ANTHROPIC_BASE_URL = "CTOK_BASE_URL",
                ANTHROPIC_AUTH_TOKEN = "CTOK_AUTH_TOKEN",
                ANTHROPIC_MODEL = "sonnet",
              },
            })
          end,
        },
      },
      strategies = {
        chat = {
          adapter = vim.fn.executable("claude") == 1 and "claude_code" or "copilot",
          -- stylua: ignore
          keymaps = {
            options                = { modes = { n = { "g?", "<localleader>?" } } },
            regenerate             = { modes = { n = "<localleader>r" } },
            stop                   = { modes = { n = "<localleader>s" } },
            clear                  = { modes = { n = "<localleader>c" } },
            codeblock              = { modes = { n = "<localleader>C" } },
            yank_code              = { modes = { n = "<localleader>y" } },
            pin                    = { modes = { n = "<localleader>p" } },
            watch                  = { modes = { n = "<localleader>w" } },
            next_chat              = { modes = { n = "<localleader>]" } },
            previous_chat          = { modes = { n = "<localleader>[" } },
            change_adapter         = { modes = { n = "<localleader>m" } },
            fold_code              = { modes = { n = "<localleader>f" } },
            debug                  = { modes = { n = "<localleader>d" } },
            system_prompt          = { modes = { n = "<localleader>P" } },
            yolo_mode              = { modes = { n = "<localleader>Y" } },
            goto_file_under_cursor = { modes = { n = "<localleader>F" } },
            copilot_stats          = { modes = { n = "<localleader>S" } },
            super_diff             = { modes = { n = "<localleader>D" } },
          },
        },
        inline = {
          adapter = "copilot",
          keymaps = {
            accept_change = { modes = { n = "<localleader>a" } },
            reject_change = { modes = { n = "<localleader>d" } },
            always_accept = { modes = { n = "<localleader>A" } },
          },
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
        {
          mode = { "n", "v" },
          { "<leader>an", group = "codecompanion", icon = { icon = " ", color = "purple" } },
        },
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

      -- stop insert mode on send via `i_CTRL-S`
      vim.api.nvim_create_autocmd("User", {
        pattern = "CodeCompanionRequestStarted",
        callback = function()
          vim.cmd("stopinsert")
        end,
      })
    end,
  },

  -- TODO: https://github.com/ravitemer/codecompanion-history.nvim

  -- status
  {
    "olimorris/codecompanion.nvim",
    dependencies = "franco-ruggeri/codecompanion-spinner.nvim",
    optional = true,
    opts = {
      extensions = {
        spinner = {},
      },
    },
  },
  -- TODO: check https://github.com/olimorris/codecompanion.nvim/commit/f962b2e
  -- {
  --   "folke/snacks.nvim",
  --   opts = function()
  --     -- see:
  --     -- - https://github.com/olimorris/codecompanion.nvim/discussions/813#discussioncomment-13081665
  --     -- - https://github.com/olimorris/dotfiles/blob/450300040e03c389db76136565da9337018c0fb6/.config/nvim/lua/plugins/custom/spinner.lua
  --     vim.api.nvim_create_autocmd("User", {
  --       pattern = { "CodeCompanionRequestStarted", "CodeCompanionRequestStreaming", "CodeCompanionRequestFinished" },
  --       group = vim.api.nvim_create_augroup("codecompanion_snacks_notifier", {}),
  --       callback = function(ev)
  --         local msg
  --         if ev.match == "CodeCompanionRequestStarted" then
  --           msg = "  Sending..."
  --         elseif ev.match == "CodeCompanionRequestStreaming" then
  --           msg = "  Generating..."
  --         elseif ev.data.status == "success" then
  --           msg = "  Completed"
  --         elseif ev.data.status == "error" then
  --           msg = "  Failed"
  --         else
  --           msg = "󰜺  Cancelled"
  --         end
  --
  --         local title
  --         local adapter = ev.data.adapter
  --         if adapter then
  --           title = (adapter.formatted_name or adapter.name or "")
  --             .. (adapter.model and adapter.model ~= "" and " (" .. adapter.model .. ")" or "")
  --         else
  --           title = "CodeCompanion"
  --         end
  --
  --         local processing = ev.match ~= "CodeCompanionRequestFinished"
  --         vim.g.user_esc_keep_notify = processing
  --
  --         ---@module "snacks"
  --         vim.notify(msg, vim.log.levels.INFO, {
  --           id = "codecompanion_status",
  --           title = title,
  --           timeout = 500,
  --           keep = function()
  --             return processing
  --           end,
  --           opts = function(notif)
  --             notif.icon = processing and Snacks.util.spinner() or " "
  --           end,
  --         } --[[@as snacks.notifier.Notif.opts]])
  --       end,
  --     })
  --   end,
  -- },
  -- {
  --   "nvim-lualine/lualine.nvim",
  --   optional = true,
  --   opts = function(_, opts)
  --     local codecompanion = require("lualine.component"):extend()
  --
  --     function codecompanion:init(options)
  --       codecompanion.super.init(self, options)
  --
  --       self.processing = false
  --       vim.api.nvim_create_autocmd("User", {
  --         group = vim.api.nvim_create_augroup("codecompanion_lualine", {}),
  --         pattern = { "CodeCompanionRequestStarted", "CodeCompanionRequestFinished" },
  --         callback = function(ev)
  --           self.processing = ev.match == "CodeCompanionRequestStarted"
  --         end,
  --       })
  --     end
  --
  --     function codecompanion:update_status()
  --       return self.processing and Snacks.util.spinner() or ""
  --     end
  --
  --     table.insert(opts.sections.lualine_x, 1, {
  --       codecompanion,
  --       color = function()
  --         return { fg = Snacks.util.color("MiniIconsPurple") }
  --       end,
  --     })
  --   end,
  -- },

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
}
