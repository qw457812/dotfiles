---@class util.ai
local M = {}
local H = {}

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

H.sidekick = {
  cli = {
    ---Copied from: https://github.com/folke/sidekick.nvim/blob/d9e1fa2124340d3337d1a3a22b2f20de0701affe/lua/sidekick/cli/init.lua#L45-L54
    ---@generic T: {name?:string, filter?:sidekick.cli.Filter}
    ---@param opts? T|string
    ---@return T
    filter_opts = function(opts)
      opts = type(opts) == "string" and { name = opts } or opts or {}
      ---@cast opts {name?:string, filter?:sidekick.cli.Filter}
      opts.filter = opts.filter or {}
      opts.filter.name = opts.name or opts.filter.name or nil
      return opts
    end,
    state = {
      ---Without select
      ---Copied from: https://github.com/folke/sidekick.nvim/blob/d2e6c6447e750a5f565ae1a832f1ca7fd8e6e8dd/lua/sidekick/cli/state.lua#L140-L174
      ---@param cb fun(state: sidekick.cli.State, attached?: boolean):any?
      ---@param name string
      ---@param opts? sidekick.cli.With
      with_quick = function(cb, name, opts)
        local State = require("sidekick.cli.state")
        local Util = require("sidekick.util")
        local Select = require("sidekick.cli.ui.select")

        opts = opts or {}
        opts.filter = opts.filter or {}
        opts.filter.name = name
        cb = vim.schedule_wrap(cb)

        ---@param state sidekick.cli.State
        local use = vim.schedule_wrap(function(state)
          if not state then
            return
          end
          local ret, attached = State.attach(state, { show = opts.show, focus = opts.focus })
          cb(ret, attached)
        end)

        local filter_attached = Util.merge(opts.filter, { attached = true })
        local attached = State.get(filter_attached)

        local tools = require("sidekick.cli.state").get(#attached == 0 and opts.filter or filter_attached)

        ---@param state? sidekick.cli.State
        local on_select = function(state)
          if state and not state.installed then
            Select.on_missing(state.tool)
            state = nil
          end
          use(state)
        end

        if #tools == 0 then
          Util.warn("No tools match the given filter")
        else
          on_select(tools[1])
        end
      end,
    },
  },
}

M.sidekick = {
  cli = {
    -- Quick commands without select
    quick = {
      ---@param name string
      ---@param opts? { focus?: boolean }
      show = function(name, opts)
        -- -- Copied from: https://github.com/folke/sidekick.nvim/pull/206
        -- local Config = require("sidekick.config")
        -- local Select = require("sidekick.cli.ui.select")
        -- local Session = require("sidekick.cli.session")
        -- local State = require("sidekick.cli.state")
        -- local Util = require("sidekick.util")
        --
        -- opts = type(opts) == "string" and { name = opts } or opts or {}
        -- local tool = Config.get_tool(name)
        -- if not tool then
        --   Util.error(("Unknown tool: %s"):format(name))
        --   return
        -- end
        -- if vim.fn.executable(tool.cmd[1]) ~= 1 then
        --   Select.on_missing(tool)
        --   return
        -- end
        -- Session.setup() -- ensure backends are registered
        -- local session = Session.new({ tool = name })
        -- session = Session.attach(session)
        -- local state = State.get_state(session)
        -- State.attach(state, { show = true, focus = opts.focus })

        opts = opts or {}
        H.sidekick.cli.state.with_quick(function() end, name, {
          focus = opts.focus,
          show = true,
        })
      end,
      ---Copied from: https://github.com/folke/sidekick.nvim/blob/d9e1fa2124340d3337d1a3a22b2f20de0701affe/lua/sidekick/cli/init.lua#L168-L173
      ---@param name string
      ---@param opts? sidekick.cli.Send
      send = function(name, opts)
        local Cli = require("sidekick.cli")
        local Util = require("sidekick.util")

        opts = type(opts) == "string" and { msg = opts } or opts
        opts = H.sidekick.cli.filter_opts(opts)

        if not opts.msg and not opts.prompt and Util.visual_mode() then
          opts.msg = "{selection}"
        end

        local msg, text = "", opts.text ---@type string?, sidekick.Text[]?
        if not text then
          msg, text = Cli.render(opts)
          if msg == "" or not text then
            Util.warn("Nothing to send.")
            return
          elseif msg == "\n" then
            msg = "" -- allow sending a new line
            text = {}
          end
        end

        H.sidekick.cli.state.with_quick(
          function(state)
            Util.exit_visual_mode()
            vim.schedule(function()
              msg = state.tool:format(text)
              state.session:send(msg .. "\n")
              if opts.submit then
                state.session:submit()
              end
            end)
          end,
          name,
          {
            focus = opts.focus,
            show = true,
          }
        )
      end,
    },
    -- ref:
    -- * https://github.com/Muizzyranking/dot-files/blob/538633c31067affd906cae0f88df8204ccd86980/config/nvim/lua/utils/plugins/sidekick.lua
    -- * https://github.com/folke/sidekick.nvim/blob/d9e1fa2124340d3337d1a3a22b2f20de0701affe/lua/sidekick/cli/init.lua#L140-L160
    ---@param opts? { filter?: sidekick.cli.Filter }
    ---@param quick? string
    kill = function(opts, quick)
      local Cli = require("sidekick.cli")
      local State = require("sidekick.cli.state")
      local Util = require("sidekick.util")

      ---@param state sidekick.cli.State
      local function kill(state)
        local session = state and state.session
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
      if quick then
        H.sidekick.cli.state.with_quick(kill, quick)
      else
        Cli.select({
          auto = true,
          filter = Util.merge(opts.filter, { started = true }),
          cb = kill,
        })
      end
    end,
    ---@param opts? { quick?: boolean, filter?: sidekick.cli.Filter }
    ---@param quick? string
    scrollback = function(opts, quick)
      local State = require("sidekick.cli.state")

      ---@param state sidekick.cli.State
      local function scrollback(state)
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
      end

      opts = opts or {}
      if quick then
        H.sidekick.cli.state.with_quick(scrollback, quick, {
          focus = false,
          show = true,
        })
      else
        -- https://github.com/folke/sidekick.nvim/blob/d9e1fa2124340d3337d1a3a22b2f20de0701affe/lua/sidekick/cli/init.lua#L123-L137
        State.with(scrollback, {
          attach = true,
          filter = opts.filter,
          focus = false,
          show = true,
        })
      end
    end,
    ---Submit (accept diff) or focus
    ---@param opts? { quick?: boolean, filter?: sidekick.cli.Filter }
    ---@param quick? string
    submit_or_focus = function(opts, quick)
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

      ---@param state sidekick.cli.State
      local function submit_or_focus(state)
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
      end

      if quick then
        H.sidekick.cli.state.with_quick(submit_or_focus, quick, {
          focus = false,
          show = true,
        })
      else
        -- https://github.com/folke/sidekick.nvim/blob/d9e1fa2124340d3337d1a3a22b2f20de0701affe/lua/sidekick/cli/init.lua#L191-L205
        State.with(submit_or_focus, {
          attach = true,
          filter = opts.filter,
          focus = false,
          show = true,
        })
      end
    end,
  },
}

return M
