---@class util.ai
local M = {}

-- https://github.com/farion1231/cc-switch/blob/7fa0a7b16648e99ef956d18c01f686dd50e843ed/src/config/claudeProviderPresets.ts
M.claude = {
  provider = {
    plan = {
      anthropic = {
        ANTHROPIC_BASE_URL = vim.env.CTOK_BASE_URL,
        ANTHROPIC_AUTH_TOKEN = vim.env.CTOK_AUTH_TOKEN,
      },
      -- https://www.kimi.com/coding/docs/third-party-agents.html
      -- https://www.kimi.com/membership/subscription
      kimi = {
        ANTHROPIC_BASE_URL = "https://api.kimi.com/coding/",
        ANTHROPIC_AUTH_TOKEN = vim.env.KIMI_API_KEY,
      },
    },
    payg = {
      -- https://platform.moonshot.cn/docs/guide/agent-support
      -- https://platform.moonshot.ai/docs/guide/agent-support
      kimi = {
        ANTHROPIC_BASE_URL = "https://api.moonshot.cn/anthropic",
        ANTHROPIC_AUTH_TOKEN = vim.env.MOONSHOT_API_KEY,
        ANTHROPIC_MODEL = "kimi-k2-thinking-turbo",
        ANTHROPIC_DEFAULT_OPUS_MODEL = "kimi-k2-thinking-turbo",
        ANTHROPIC_DEFAULT_SONNET_MODEL = "kimi-k2-thinking-turbo",
        ANTHROPIC_DEFAULT_HAIKU_MODEL = "kimi-k2-thinking-turbo",
        CLAUDE_CODE_SUBAGENT_MODEL = "kimi-k2-thinking-turbo",
      },
      glm = {
        ANTHROPIC_BASE_URL = "https://open.bigmodel.cn/api/anthropic",
        ANTHROPIC_AUTH_TOKEN = vim.env.ZHIPU_API_KEY,
        API_TIMEOUT_MS = "3000000",
      },
      minimax = {
        ANTHROPIC_BASE_URL = "https://api.minimax.io/anthropic",
        ANTHROPIC_AUTH_TOKEN = vim.env.MINIMAX_API_KEY,
        API_TIMEOUT_MS = "3000000",
        ANTHROPIC_MODEL = "MiniMax-M2",
        ANTHROPIC_SMALL_FAST_MODEL = "MiniMax-M2",
        ANTHROPIC_DEFAULT_SONNET_MODEL = "MiniMax-M2",
        ANTHROPIC_DEFAULT_OPUS_MODEL = "MiniMax-M2",
        ANTHROPIC_DEFAULT_HAIKU_MODEL = "MiniMax-M2",
      },
    },
  },
}

M.sidekick = {
  cli = {
    -- ref:
    -- * https://github.com/Muizzyranking/dot-files/blob/538633c31067affd906cae0f88df8204ccd86980/config/nvim/lua/utils/plugins/sidekick.lua
    -- * https://github.com/folke/sidekick.nvim/blob/d9e1fa2124340d3337d1a3a22b2f20de0701affe/lua/sidekick/cli/init.lua#L140-L160
    ---@param opts? { filter?: sidekick.cli.Filter }
    kill = function(opts)
      local Cli = require("sidekick.cli")
      local State = require("sidekick.cli.state")
      local Util = require("sidekick.util")

      ---@param state sidekick.cli.State
      local function kill(state)
        if not state then
          return
        end
        State.detach(state)
        if state.session and state.session.mux_session then
          U.confirm(("Kill session %q?"):format(state.session.mux_session), function()
            if state.session.backend == "tmux" or state.session.mux_backend == "tmux" then
              Util.exec({ "tmux", "kill-session", "-t", state.session.mux_session })
            end
          end)
        end
      end

      opts = opts or {}
      Cli.select({
        auto = true,
        filter = Util.merge(opts.filter, { started = true }),
        cb = kill,
      })
    end,
    ---@param opts? { filter?: sidekick.cli.Filter }
    scrollback = function(opts)
      local State = require("sidekick.cli.state")

      opts = opts or {}
      -- https://github.com/folke/sidekick.nvim/blob/d9e1fa2124340d3337d1a3a22b2f20de0701affe/lua/sidekick/cli/init.lua#L123-L137
      State.with(function(state)
        if not (state.terminal and state.terminal:is_running()) then
          return
        end
        -- focus: https://github.com/folke/sidekick.nvim/blob/83b6815c0ed738576f101aad31c79b885c892e0f/lua/sidekick/cli/terminal.lua#L380-L389
        if not state.terminal:is_focused() then
          vim.api.nvim_set_current_win(assert(state.terminal.win))
        end
        -- scrollback
        vim.defer_fn(function()
          if vim.fn.mode() ~= "n" then
            vim.cmd.stopinsert()
          end
        end, 80)
      end, {
        attach = true,
        filter = opts.filter,
        focus = false,
        show = true,
      })
    end,
    ---@param opts? { filter?: sidekick.cli.Filter, focus?: boolean }
    accept = function(opts)
      local State = require("sidekick.cli.state")
      local Util = require("sidekick.util")

      opts = opts or {}

      local is_visible = false
      for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        if vim.bo[vim.api.nvim_win_get_buf(w)].filetype == "sidekick_terminal" then
          is_visible = true
          break
        end
      end

      -- https://github.com/folke/sidekick.nvim/blob/d9e1fa2124340d3337d1a3a22b2f20de0701affe/lua/sidekick/cli/init.lua#L191-L205
      State.with(function(state)
        if not is_visible then
          return
        end
        if state.session and state.session.mux_session then
          if state.session.backend == "tmux" or state.session.mux_backend == "tmux" then
            vim.schedule(function()
              -- https://github.com/folke/sidekick.nvim/blob/41dec4dcdf0c8fe17f5f2e9eeced4645a88afb0d/lua/sidekick/cli/session/tmux.lua#L185-L187
              Util.exec({ "tmux", "send-keys", "-t", state.session.mux_session, "Enter" })
            end)
          end
        end
      end, {
        attach = true,
        filter = opts.filter,
        focus = opts.focus == true,
        show = true,
      })
    end,
  },
}

return M
