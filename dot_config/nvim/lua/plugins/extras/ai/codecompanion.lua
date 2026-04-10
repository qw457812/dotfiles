---@return boolean True if focus changed, false otherwise
local function focus_last_chat()
  local chat = require("codecompanion").last_chat()
  if not (chat and chat.ui:is_visible()) then
    return false
  end
  vim.api.nvim_set_current_win(chat.ui.winnr)
  U.stop_visual_mode()
  -- vim.cmd("startinsert!")
  return true
end

---@type LazySpec
return {
  {
    "olimorris/codecompanion.nvim",
    cmd = "CodeCompanion",
    keys = {
      {
        "<leader>am",
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
        "<leader>am",
        function()
          vim.cmd("CodeCompanionChat Add")
          focus_last_chat()
        end,
        desc = "CodeCompanion",
        mode = "x",
      },
      {
        "<leader>anf",
        function()
          require("codecompanion").toggle({
            window_opts = {
              layout = "float",
              height = 0.8,
              width = 0.8,
              border = "rounded",
              title = "   CodeCompanion ",
            },
          })
        end,
        desc = "Floating",
      },
      { "<leader>ani", "<cmd>CodeCompanion<CR>", desc = "Inline", mode = { "n", "x" } },
      { "<leader>ana", "<cmd>CodeCompanionActions<CR>", desc = "Actions", mode = { "n", "x" } },
      { "<leader>ann", "<cmd>CodeCompanionChat<CR>", desc = "New Chat", mode = { "n", "x" } },
      {
        "<leader>anc",
        "<cmd>CodeCompanionChat adapter=claude_code<CR>",
        desc = "Claude Code ACP",
        mode = { "n", "x" },
      },
      { "<leader>anp", "<cmd>CodeCompanionChat adapter=copilot<CR>", desc = "Copilot", mode = { "n", "x" } },
    },
    opts = {
      adapters = {
        http = {
          copilot = function()
            return require("codecompanion.adapters").extend("copilot", {
              schema = {
                model = {
                  -- https://docs.github.com/en/copilot/concepts/billing/copilot-requests#model-multipliers
                  default = "gpt-5-mini",
                },
              },
            })
          end,
        },
        acp = {
          -- requires `npm i -g @agentclientprotocol/claude-agent-acp`
          claude_code = function()
            return require("codecompanion.adapters").extend("claude_code", {
              env = (function()
                local env = vim.deepcopy(U.ai.claude.provider.plan.synthetic)
                for k, v in pairs(env) do
                  if v == "" then
                    env[k] = nil
                  end
                end
                return env
              end)(),
            })
          end,
        },
      },
      interactions = {
        chat = {
          adapter = vim.fn.executable("claude-agent-acp") == 1 and "claude_code" or "copilot",
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
              -- default_tools = { "files" }, -- ACP does not need it
            },
          },
          -- stylua: ignore
          keymaps = {
            options                = { modes = { n = { "g?", "<localleader>?" } } },
            regenerate             = { modes = { n = "<localleader>r" } },
            close                  = { modes = { n = "<localleader>C", i = {} } },
            stop                   = { modes = { n = "<localleader>s" } },
            clear                  = { modes = { n = "<localleader>c" } },
            codeblock              = { modes = { n = "<localleader>`" } },
            yank_code              = { modes = { n = "<localleader>y" } },
            buffer_sync_all        = { modes = { n = "<localleader>ba" } },
            buffer_sync_diff       = { modes = { n = "<localleader>bd" } },
            next_chat              = { modes = { n = "<localleader>j" } },
            previous_chat          = { modes = { n = "<localleader>k" } },
            change_adapter         = { modes = { n = "<localleader>m" } },
            fold_code              = { modes = { n = "<localleader>f" } },
            debug                  = { modes = { n = "<localleader>D" } },
            system_prompt          = { modes = { n = "<localleader>P" } },
            rules                  = { modes = { n = "<localleader>M" } },
            clear_approvals        = { modes = { n = "<localleader>X" } },
            yolo_mode              = { modes = { n = "<localleader>Y" } },
            goto_file_under_cursor = { modes = { n = "<localleader>F" } },
            copilot_stats          = { modes = { n = "<localleader>S" } },
          },
        },
        shared = {
          keymaps = {
            view_diff = { modes = { n = "<localleader>d" } },
            always_accept = { modes = { n = "<localleader>A" } },
            accept_change = { modes = { n = "<localleader>a" } },
            reject_change = { modes = { n = "<localleader>x" } },
            cancel = { modes = { n = "<C-c>" } },
            next_hunk = { modes = { n = "]h" } },
            previous_hunk = { modes = { n = "[h" } },
          },
        },
      },
      display = {
        action_palette = {
          provider = "default",
        },
        chat = {
          -- show_settings = true,
          -- start_in_insert_mode = true,
          window = {
            layout = vim.o.columns >= 120 and "vertical" or "horizontal",
            height = 0.5,
            width = 0.4,
          },
        },
      },
      opts = {
        -- language = "Chinese",
      },
    },
  },
  {
    "folke/which-key.nvim",
    opts = {
      spec = {
        {
          mode = { "n", "x" },
          { "<leader>an", group = "codecompanion" },
        },
      },
    },
  },
  {
    "olimorris/codecompanion.nvim",
    optional = true,
    opts = function()
      vim.api.nvim_create_autocmd("FileType", {
        group = vim.api.nvim_create_augroup("codecompanion_keymaps", { clear = true }),
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
            group = vim.api.nvim_create_augroup("codecompanion_keymaps_" .. buf, { clear = true }),
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

      vim.api.nvim_create_autocmd("BufWinEnter", {
        group = vim.api.nvim_create_augroup("codecompanion_diff_keymaps", { clear = true }),
        callback = vim.schedule_wrap(function(ev)
          local buf = ev.buf
          if not (vim.api.nvim_buf_is_valid(buf) and U.ai.codecompanion.is_diff(buf)) then
            return
          end

          local shared_keymaps = require("codecompanion.config").config.interactions.shared.keymaps
          local accept_key = shared_keymaps.accept_change.modes.n
          local reject_key = shared_keymaps.reject_change.modes.n
          vim.keymap.set(
            "n",
            "<CR>",
            type(accept_key) == "table" and accept_key[1] or accept_key,
            { buffer = buf, remap = true, desc = "Accept Diff (CodeCompanion)" }
          )
          vim.keymap.set(
            "n",
            "<C-c>",
            type(reject_key) == "table" and reject_key[1] or reject_key,
            { buffer = buf, remap = true, desc = "Reject Diff (CodeCompanion)" }
          )
        end),
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
          ---@module "codecompanion._extensions.history"
          ---@type CodeCompanion.History.Opts
          opts = {
            keymap = "<localleader>h",
            save_chat_keymap = { n = {}, i = {} }, -- disable since auto_save is enabled (by default), "<Nop>" works too
            expiration_days = 30,
            picker_keymaps = {
              rename = { n = "<localleader>r" },
              delete = { n = "<localleader>d" },
              duplicate = { n = "<localleader>y", i = "<M-y>" },
            },
            auto_generate_title = false, -- buggy
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
            ---@diagnostic disable-next-line: missing-fields
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
  -- TODO: check:
  -- - https://github.com/olimorris/codecompanion.nvim/commit/f962b2e
  -- - https://github.com/lalitmee/codecompanion-spinners.nvim
  {
    "folke/snacks.nvim",
    opts = function()
      -- see:
      -- - https://github.com/olimorris/codecompanion.nvim/discussions/813#discussioncomment-13081665
      -- - https://github.com/olimorris/dotfiles/blob/450300040e03c389db76136565da9337018c0fb6/.config/nvim/lua/plugins/custom/spinner.lua
      vim.api.nvim_create_autocmd("User", {
        pattern = { "CodeCompanionRequestStarted", "CodeCompanionRequestStreaming", "CodeCompanionRequestFinished" },
        group = vim.api.nvim_create_augroup("codecompanion_snacks_notifier", {}),
        callback = function(ev)
          local msg
          if ev.match == "CodeCompanionRequestStarted" then
            msg = "  Sending..."
          elseif ev.match == "CodeCompanionRequestStreaming" then
            msg = "  Generating..."
          elseif ev.data.status == "success" then
            msg = "󰗡  Done!"
          elseif ev.data.status == "error" then
            msg = "  Failed"
          else
            msg = "󰜺  Cancelled"
          end

          local title
          local adapter = ev.data.adapter
          if adapter then
            title = (adapter.formatted_name or adapter.name or "")
              .. (adapter.model and adapter.model ~= "" and " (" .. adapter.model .. ")" or "")
          else
            title = "CodeCompanion"
          end

          local processing = ev.match ~= "CodeCompanionRequestFinished"
          vim.g.user_esc_keep_notify = processing

          vim.notify(msg, vim.log.levels.INFO, {
            id = "codecompanion_status",
            title = title,
            timeout = 500,
            keep = function(notif)
              -- if notif.win and notif.win:valid() then
              --   vim.w[notif.win.win].user_notify_keep = processing
              --   vim.b[notif.win.buf].user_notify_keep = processing
              -- end
              return processing
            end,
            opts = function(notif)
              notif.icon = processing and Snacks.util.spinner() or ""
            end,
            -- style = "history",
            style = function(buf, notif, ctx)
              ctx.opts.border = "none"
              -- copied from: https://github.com/folke/snacks.nvim/blob/a13c891a59ec0e67a75824fe1505a9e57fbfca0f/lua/snacks/notifier.lua#L186-L212
              local lines = vim.split(notif.msg, "\n", { plain = true })
              local prefix = {
                { notif.icon, ctx.hl.icon },
                { notif.title, ctx.hl.title },
              }
              prefix = vim.tbl_filter(function(v)
                return (v[1] or "") ~= ""
              end, prefix)
              local prefix_width = 0
              for i = 1, #prefix do
                prefix_width = prefix_width + vim.fn.strdisplaywidth(prefix[i * 2 - 1][1]) + 1
                table.insert(prefix, i * 2, { " " })
              end
              local top = vim.api.nvim_buf_line_count(buf)
              local empty = top == 1 and #vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] == 0
              top = empty and 0 or top
              lines[1] = string.rep(" ", prefix_width) .. (lines[1] or "")
              vim.api.nvim_buf_set_lines(buf, top, -1, false, lines)
              vim.api.nvim_buf_set_extmark(buf, ctx.ns, top, 0, {
                virt_text = prefix,
                virt_text_pos = "overlay",
                priority = 10,
              })
            end,
          } --[[@as snacks.notifier.Notif.opts]])
        end,
      })
    end,
  },
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
