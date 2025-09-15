---@return boolean True if focus changed, false otherwise
local function focus_last_chat()
  local chat = require("codecompanion").last_chat()
  if not (chat and chat.ui:is_visible()) then
    return false
  end
  vim.api.nvim_set_current_win(chat.ui.winnr)
  U.stop_visual_mode()
  vim.cmd("startinsert!")
  return true
end

-- https://github.com/olimorris/dotfiles/blob/main/.config/nvim/lua/plugins/coding.lua
---@type LazySpec
return {
  {
    "olimorris/codecompanion.nvim",
    cmd = "CodeCompanion",
    keys = {
      {
        "<leader>ao",
        -- "<cmd>CodeCompanionChat Toggle<CR>",
        function()
          -- https://github.com/olimorris/codecompanion.nvim/blob/3f7fd6292b9d43d38e9760f43b581652210b0349/lua/codecompanion/init.lua#L178-L192
          if not focus_last_chat() then
            require("codecompanion").toggle()
          end
        end,
        desc = "CodeCompanion",
        -- mode = { "n", "x" }, -- not working in visual mode, using `:CodeCompanionChat Add` instead
      },
      {
        "<leader>ao",
        function()
          vim.cmd("CodeCompanionChat Add")
          focus_last_chat()
        end,
        desc = "Add to Chat",
        mode = "x",
      },
      { "<leader>ani", "<cmd>CodeCompanion<CR>", desc = "Inline", mode = { "n", "x" } },
      { "<leader>ana", "<cmd>CodeCompanionActions<CR>", desc = "Actions", mode = { "n", "x" } },
      { "<leader>anN", "<cmd>CodeCompanionChat<CR>", desc = "New Chat", mode = { "n", "x" } },
      { "<leader>ann", "<cmd>CodeCompanionChat claude_code<CR>", desc = "Claude Code ACP", mode = { "n", "x" } },
      { "<leader>anp", "<cmd>CodeCompanionChat copilot_gpt_5<CR>", desc = "Copilot GPT-5", mode = { "n", "x" } },
      {
        "<leader>ans",
        "<cmd>CodeCompanionChat copilot_claude<CR>",
        desc = "Copilot Claude Sonnet 4",
        mode = { "n", "x" },
      },
    },
    opts = {
      adapters = {
        http = {
          copilot_claude = function()
            return require("codecompanion.adapters").extend("copilot", {
              name = "copilot_claude",
              formatted_name = "Copilot Claude Sonnet 4",
              schema = {
                model = {
                  -- https://docs.github.com/en/copilot/concepts/billing/copilot-requests#model-multipliers
                  default = "claude-sonnet-4",
                },
              },
            })
          end,
          copilot_gpt_5 = function()
            return require("codecompanion.adapters").extend("copilot", {
              name = "copilot_gpt_5",
              formatted_name = "Copilot GPT-5",
              schema = {
                model = {
                  default = "gpt-5",
                },
              },
            })
          end,
        },
        acp = {
          claude_code = function()
            return require("codecompanion.adapters").extend("claude_code", {
              env = {
                ANTHROPIC_BASE_URL = "CTOK_BASE_URL",
                ANTHROPIC_AUTH_TOKEN = "CTOK_AUTH_TOKEN",
              },
            })
          end,
        },
      },
      strategies = {
        chat = {
          adapter = "copilot",
          roles = {
            ---@param adapter CodeCompanion.HTTPAdapter|CodeCompanion.ACPAdapter
            ---@return string
            llm = function(adapter)
              return adapter.formatted_name
            end,
            user = "User",
          },
          tools = {
            opts = {
              default_tools = { "files" },
            },
          },
          -- stylua: ignore
          keymaps = {
            options                = { modes = { n = { "g?", "<localleader>?" } } },
            regenerate             = { modes = { n = "<localleader>r" } },
            stop                   = { modes = { n = "<localleader>s" } },
            clear                  = { modes = { n = "<localleader>c" } },
            codeblock              = { modes = { n = "<localleader>`" } },
            yank_code              = { modes = { n = "<localleader>y" } },
            pin                    = { modes = { n = "<localleader>p" } },
            watch                  = { modes = { n = "<localleader>w" } },
            next_chat              = { modes = { n = "<localleader>j" } },
            previous_chat          = { modes = { n = "<localleader>k" } },
            change_adapter         = { modes = { n = "<localleader>m" } },
            fold_code              = { modes = { n = "<localleader>f" } },
            debug                  = { modes = { n = "<localleader>d" } },
            system_prompt          = { modes = { n = "<localleader>P" } },
            memory                 = { modes = { n = "<localleader>M" } },
            yolo_mode              = { modes = { n = "<localleader>Y" } },
            goto_file_under_cursor = { modes = { n = "<localleader>F" } },
            copilot_stats          = { modes = { n = "<localleader>S" } },
            super_diff             = { modes = { n = "<localleader>D" } },
            _acp_allow_always      = { modes = { n = "<S-Tab>" } },
            _acp_allow_once        = { modes = { n = "<C-s>" } },
            _acp_reject_once       = { modes = { n = "<C-c>" } },
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
      memory = {
        agents_md = {
          description = "One AGENTS.md works across many agents",
          -- `enabled` not working
          ------@return boolean
          ---enabled = function()
          ---  -- do not add AGENTS.md to memory if CLAUDE.md exists
          ---  return vim.fn.filereadable("CLAUDE.md") == 0
          ---end,
          files = { "AGENTS.md" },
        },
        claude = {
          description = "Claude Code memory files",
          parser = "claude",
          files = {
            "~/.claude/CLAUDE.md",
            "CLAUDE.md",
            "CLAUDE.local.md",
          },
        },
        opts = {
          chat = {
            enabled = true,
            default_memory = {
              -- "agents_md", -- `opts.memory.agents_md.enabled` not working
              "claude",
            },
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
      opts = {
        language = "Chinese",
      },
    },
  },
  {
    "folke/which-key.nvim",
    opts = {
      spec = {
        {
          mode = { "n", "v" },
          { "<leader>an", group = "codecompanion" },
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
          vim.b[buf].user_lualine_filename = "codecompanion"

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

  -- history
  {
    "olimorris/codecompanion.nvim",
    dependencies = "ravitemer/codecompanion-history.nvim",
    optional = true,
    keys = {
      { "<leader>anh", "<cmd>CodeCompanionHistory<CR>", desc = "History" },
    },
    opts = {
      extensions = {
        history = {
          opts = {
            keymap = "<localleader>h",
            save_chat_keymap = { n = {}, i = {} }, -- disable since auto_save is enabled (by default), "<Nop>" works too
            expiration_days = 30,
            picker_keymaps = {
              rename = { n = "<localleader>r" },
              delete = { n = "<localleader>d" },
              duplicate = { n = "<localleader>y", i = "<M-y>" },
            },
            title_generation_opts = {
              adapter = "copilot",
            },
            -- disable summary
            summary = {
              create_summary_keymap = { n = {} },
              browse_summaries_keymap = { n = {} },
              generation_opts = {
                adapter = "copilot",
              },
            },
            -- disable memory
            memory = {
              auto_create_memories_on_summary_generation = false,
            },
          },
        },
      },
    },
  },

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
}
