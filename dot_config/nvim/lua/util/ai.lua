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
        local session = state.session
        if not session then
          return
        end
        State.detach(state)
        if session.mux_session then
          U.confirm(("Kill session %q?"):format(session.mux_session), function()
            if session.backend == "tmux" or session.mux_backend == "tmux" then
              Util.exec({ "tmux", "kill-session", "-t", session.mux_session })
            else
              -- TODO: zellij
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
        local terminal = state.terminal
        if not (terminal and terminal:is_running() and terminal:buf_valid() and terminal:win_valid()) then
          return
        end

        -- focus: https://github.com/folke/sidekick.nvim/blob/83b6815c0ed738576f101aad31c79b885c892e0f/lua/sidekick/cli/terminal.lua#L380-L389
        if not terminal:is_focused() then
          vim.api.nvim_set_current_win(terminal.win)
        end

        vim.defer_fn(function()
          if vim.fn.mode() ~= "t" then
            return
          end

          -- https://github.com/folke/sidekick.nvim/blob/83b6815c0ed738576f101aad31c79b885c892e0f/lua/sidekick/cli/terminal.lua#L249-L254
          local lines = vim.api.nvim_buf_get_lines(terminal.buf, 0, -1, false)
          while #lines > 0 and lines[#lines] == "" do
            table.remove(lines)
          end
          local cursor = vim.api.nvim_win_get_cursor(terminal.win)
          local is_ready = #lines > 5 and cursor[1] > 3
          if not is_ready then
            return -- new terminal, nothing to scroll
          end

          vim.cmd.stopinsert()
        end, 100)
      end, {
        attach = true,
        filter = opts.filter,
        focus = false,
        show = true,
      })
    end,
    ---Submit (accept diff) or focus
    ---@param opts? { filter?: sidekick.cli.Filter }
    submit_or_focus = function(opts)
      local State = require("sidekick.cli.state")
      local Util = require("sidekick.util")

      opts = opts or {}

      if vim.bo.filetype == "sidekick_terminal" and vim.fn.mode() ~= "t" then
        vim.cmd.startinsert()
        return
      end

      local is_open = false
      for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        if vim.bo[vim.api.nvim_win_get_buf(w)].filetype == "sidekick_terminal" then
          is_open = true
          break
        end
      end

      -- https://github.com/folke/sidekick.nvim/blob/d9e1fa2124340d3337d1a3a22b2f20de0701affe/lua/sidekick/cli/init.lua#L191-L205
      State.with(function(state)
        local terminal, session = state.terminal, state.session
        if not (session and terminal and terminal:is_running() and terminal:buf_valid() and terminal:win_valid()) then
          return
        end

        if not is_open then
          terminal:focus()
          return -- do not submit if terminal was not open
        end

        vim.schedule(function()
          local changedtick = vim.b[terminal.buf].changedtick

          if session.mux_session then
            if session.backend == "tmux" or session.mux_backend == "tmux" then
              -- submit: https://github.com/folke/sidekick.nvim/blob/41dec4dcdf0c8fe17f5f2e9eeced4645a88afb0d/lua/sidekick/cli/session/tmux.lua#L185-L187
              Util.exec({ "tmux", "send-keys", "-t", session.mux_session, "Enter" })

              vim.defer_fn(function()
                if vim.b[terminal.buf].changedtick == changedtick then
                  -- focus if <cr> had no effect
                  terminal:focus()
                elseif terminal.scrollback and terminal.scrollback:is_open() then
                  -- switch from scrollback to terminal if <cr> had effect
                  terminal.scrollback:close()
                end
              end, 50)
            else
              -- TODO: zellij
            end
          else
            local win = vim.api.nvim_get_current_win()
            terminal:focus()
            vim.defer_fn(function()
              -- submit, need to call `terminal:focus()` first
              vim.api.nvim_feedkeys(vim.keycode("<CR>"), "n", false)

              vim.defer_fn(function()
                if vim.b[terminal.buf].changedtick ~= changedtick and vim.api.nvim_win_is_valid(win) then
                  -- back to original window if <cr> had effect, align with tmux backend behavior
                  vim.api.nvim_set_current_win(win)
                end
              end, 50)
            end, 20)
          end
        end)
      end, {
        attach = true,
        filter = opts.filter,
        focus = false,
        show = true,
      })
    end,
  },
}

return M
