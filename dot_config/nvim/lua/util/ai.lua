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
      kimi = {
        ANTHROPIC_BASE_URL = "https://api.kimi.com/coding/",
        ANTHROPIC_AUTH_TOKEN = vim.env.KIMI_API_KEY,
      },
    },
    payg = {
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
          if state.session.backend == "tmux" or state.session.mux_backend == "tmux" then
            Util.exec({ "tmux", "kill-session", "-t", state.session.mux_session })
          end
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
      opts = opts or {}
      require("sidekick.cli").focus({ filter = opts.filter })

      -- auto enter scrollback
      local executed = false
      local mux_enabled = vim.tbl_get(LazyVim.opts("sidekick.nvim"), "cli", "mux", "enabled")
      local id = vim.api.nvim_create_autocmd("TermEnter", {
        group = vim.api.nvim_create_augroup("sidekick_scrollback_oneshot", { clear = true }),
        pattern = mux_enabled and { "term://*:*tmux", "term://*:*zellij" } or nil,
        callback = function(ev)
          if vim.bo[ev.buf].filetype ~= "sidekick_terminal" then
            return
          end
          vim.schedule(function()
            vim.cmd.stopinsert()
          end)
          executed = true
          return true
        end,
      })
      -- to auto enter scrollback after sidekick_cli picker confirm
      -- autocmd -> append `vim.cmd.stopinsert()` to `cb` of `State.with` in `require("sidekick.cli").focus` here:
      -- https://github.com/folke/sidekick.nvim/blob/d9e1fa2124340d3337d1a3a22b2f20de0701affe/lua/sidekick/cli/init.lua#L124-L131
      vim.defer_fn(function()
        if not executed then
          vim.api.nvim_del_autocmd(id)
        end
      end, 500)
    end,
  },
}

return M
