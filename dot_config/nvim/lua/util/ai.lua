---@class util.ai
local M = {}
local H = {}

---@class vim.var_accessor
---https://github.com/folke/sidekick.nvim/blob/83b6815c0ed738576f101aad31c79b885c892e0f/lua/sidekick/cli/terminal.lua#L375
---https://github.com/folke/sidekick.nvim/blob/83b6815c0ed738576f101aad31c79b885c892e0f/lua/sidekick/cli/terminal.lua#L154
---@field sidekick_cli? sidekick.cli.Tool

---@class vim.var_accessor
---https://github.com/folke/sidekick.nvim/blob/83b6815c0ed738576f101aad31c79b885c892e0f/lua/sidekick/cli/terminal.lua#L376
---@field sidekick_session_id? string

-- https://github.com/farion1231/cc-switch/blob/7fa0a7b16648e99ef956d18c01f686dd50e843ed/src/config/claudeProviderPresets.ts
M.claude = {
  provider = {
    plan = {
      -- curl -s -X POST "$CLAUDE_RELAY_SERVICE_URL/apiStats/api-key/test" -H "Content-Type: application/json" -d "{\"apiKey\":\"$CLAUDE_RELAY_SERVICE_API_KEY\"}"
      anthropic = vim.env.CLAUDE_RELAY_SERVICE_URL and {
        ANTHROPIC_BASE_URL = vim.env.CLAUDE_RELAY_SERVICE_URL .. "/api",
        ANTHROPIC_AUTH_TOKEN = vim.env.CLAUDE_RELAY_SERVICE_API_KEY,
      } or {},
      -- https://z.ai/manage-apikey/subscription
      glm = {
        ANTHROPIC_BASE_URL = "https://api.z.ai/api/anthropic",
        ANTHROPIC_AUTH_TOKEN = vim.env.ZAI_API_KEY,
        API_TIMEOUT_MS = "3000000",
        ANTHROPIC_DEFAULT_HAIKU_MODEL = "glm-4.7", -- glm-4.5-air is not good enough
      },
      -- https://www.kimi.com/code/docs/more/third-party-agents.html
      -- https://www.kimi.com/membership/subscription
      kimi = {
        ANTHROPIC_BASE_URL = "https://api.kimi.com/coding/",
        ANTHROPIC_AUTH_TOKEN = vim.env.KIMI_API_KEY,
      },
    },
    payg = {
      -- https://openrouter.ai/docs/guides/guides/claude-code-integration
      openrouter = {
        ANTHROPIC_BASE_URL = "https://openrouter.ai/api",
        ANTHROPIC_AUTH_TOKEN = vim.env.CC_OPENROUTER_API_KEY,
        ANTHROPIC_API_KEY = "",
      },
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
      minimax = {
        ANTHROPIC_BASE_URL = "https://api.minimax.io/anthropic",
        ANTHROPIC_AUTH_TOKEN = vim.env.MINIMAX_API_KEY,
        API_TIMEOUT_MS = "3000000",
        ANTHROPIC_MODEL = "MiniMax-M2.1",
        ANTHROPIC_SMALL_FAST_MODEL = "MiniMax-M2.1",
        ANTHROPIC_DEFAULT_SONNET_MODEL = "MiniMax-M2.1",
        ANTHROPIC_DEFAULT_OPUS_MODEL = "MiniMax-M2.1",
        ANTHROPIC_DEFAULT_HAIKU_MODEL = "MiniMax-M2.1",
      },
    },
  },
}
M.claude.provider.payg.glm = M.claude.provider.plan.glm

---@param buf integer
---@param win integer
---@return string[]
function H.visible_lines(buf, win)
  return vim.api.nvim_buf_get_lines(buf, vim.fn.line("w0", win) - 1, vim.fn.line("w$", win), false)
end

---@param key string
---@return string
function H.nvim_key_to_tmux(key)
  return (
    key
      :gsub("<[Cc]%-(%w)>", "C-%1")
      :gsub("<[MmAa]%-(%w)>", "M-%1")
      :gsub("<[Ss]%-(%a)>", string.upper)
      :gsub("<[Ss]%-(%w+)>", "S-%1")
      :gsub("<[Cc][Rr]>", "Enter")
      :gsub("<[Ee][Ss][Cc]>", "Escape")
      :gsub("<[Ss]%-[Tt][Aa][Bb]>", "BTab")
      :gsub("<[Tt][Aa][Bb]>", "Tab")
      :gsub("<[Bb][Ss]>", "BSpace")
      :gsub("<[Ss][Pp][Aa][Cc][Ee]>", "Space")
      :gsub("<[Uu][Pp]>", "Up")
      :gsub("<[Dd][Oo][Ww][Nn]>", "Down")
      :gsub("<[Ll][Ee][Ff][Tt]>", "Left")
      :gsub("<[Rr][Ii][Gg][Hh][Tt]>", "Right")
      :gsub("<[Hh][Oo][Mm][Ee]>", "Home")
      :gsub("<[Ee][Nn][Dd]>", "End")
      :gsub("<[Pp][Aa][Gg][Ee][Uu][Pp]>", "PageUp")
      :gsub("<[Pp][Aa][Gg][Ee][Dd][Oo][Ww][Nn]>", "PageDown")
      :gsub("<[Ff](%d+)>", "F%1")
  )
end

H.sidekick = {
  cli = {
    ---@return { win: integer, buf: integer, tool: sidekick.cli.Tool, terminal: sidekick.cli.Terminal, session: sidekick.cli.Session }[]
    list_visible = function()
      local Session = require("sidekick.cli.session")
      local Terminal = require("sidekick.cli.terminal")

      local ret = {}
      for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        local b = vim.api.nvim_win_get_buf(w)
        -- vim.api.nvim_get_chan_info(vim.bo.channel)
        if vim.bo[b].filetype == "sidekick_terminal" then
          local session_id = assert(vim.w[w].sidekick_session_id)
          table.insert(ret, {
            win = w,
            buf = b,
            tool = assert(vim.w[w].sidekick_cli),
            terminal = assert(Terminal.get(session_id)),
            session = assert(Session.attached()[session_id]),
          })
        end
      end
      return ret
    end,
    ---https://github.com/folke/sidekick.nvim/blob/83b6815c0ed738576f101aad31c79b885c892e0f/lua/sidekick/cli/terminal.lua#L249-L254
    ---@param buf integer
    ---@param win integer
    ---@return boolean
    is_ready = function(buf, win)
      local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
      while #lines > 0 and lines[#lines] == "" do
        table.remove(lines)
      end
      local cursor = vim.api.nvim_win_get_cursor(win)
      return #lines > 5 and cursor[1] > 3
    end,
    quick = {
      ---Skip the select step.
      ---Copied from: https://github.com/folke/sidekick.nvim/blob/d2e6c6447e750a5f565ae1a832f1ca7fd8e6e8dd/lua/sidekick/cli/state.lua#L140-L174
      ---@param cb fun(state: sidekick.cli.State, attached?: boolean):any?
      ---@param name string
      ---@param opts? sidekick.cli.With [attach, all, filter.name] are ignored
      with_state = function(cb, name, opts)
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
    -- quick commands that skip the select step
    quick = {
      ---Copied from: https://github.com/folke/sidekick.nvim/blob/d9e1fa2124340d3337d1a3a22b2f20de0701affe/lua/sidekick/cli/init.lua#L85-L96
      ---@param name string
      ---@param opts? { focus?: boolean }
      show = function(name, opts)
        opts = opts or {}
        H.sidekick.cli.quick.with_state(function() end, name, {
          focus = opts.focus,
          show = true,
        })
      end,
      ---Copied from: https://github.com/folke/sidekick.nvim/blob/d9e1fa2124340d3337d1a3a22b2f20de0701affe/lua/sidekick/cli/init.lua#L168-L173
      ---@param name string
      ---@param opts? sidekick.cli.Send both [name] and [opts ignored by H.sidekick.cli.quick.with_state] are ignored
      send = function(name, opts)
        local Cli = require("sidekick.cli")
        local Util = require("sidekick.util")

        opts = type(opts) == "string" and { msg = opts } or opts or {}

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

        H.sidekick.cli.quick.with_state(
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
        H.sidekick.cli.quick.with_state(kill, quick)
      else
        Cli.select({
          auto = true,
          filter = Util.merge(opts.filter, { started = true }),
          cb = kill,
        })
      end
    end,
    ---@param opts? { filter?: sidekick.cli.Filter }
    ---@param quick? string
    scrollback = function(opts, quick)
      local State = require("sidekick.cli.state")

      ---@param terminal sidekick.cli.Terminal
      local function norm(terminal)
        -- focus: https://github.com/folke/sidekick.nvim/blob/83b6815c0ed738576f101aad31c79b885c892e0f/lua/sidekick/cli/terminal.lua#L380-L389
        if not terminal:is_focused() then
          vim.api.nvim_set_current_win(terminal.win)
        end

        vim.defer_fn(function()
          if vim.fn.mode() ~= "t" then
            return
          end
          if not H.sidekick.cli.is_ready(terminal.buf, terminal.win) then
            return -- new terminal, nothing to scroll
          end

          vim.cmd.stopinsert()
        end, 100)
      end

      ---@param state sidekick.cli.State
      local function scrollback(state)
        local terminal = state.terminal
        if not (terminal and terminal:is_running() and terminal:buf_valid() and terminal:win_valid()) then
          return
        end

        norm(terminal)
      end

      opts = opts or {}

      -- skip the select step if only one terminal visible, regardless of multiple attached sessions
      local visible = H.sidekick.cli.list_visible()
      if #visible == 1 then
        if not (quick and quick ~= visible[1].tool.name) then
          norm(visible[1].terminal)
          return
        end
      end

      if quick then
        H.sidekick.cli.quick.with_state(scrollback, quick, {
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
    ---@param opts? { filter?: sidekick.cli.Filter }
    ---@param quick? string
    submit_or_focus = function(opts, quick)
      local State = require("sidekick.cli.state")
      local Util = require("sidekick.util")

      ---@param terminal sidekick.cli.Terminal
      ---@param session sidekick.cli.Session
      local function submit(terminal, session)
        vim.schedule(function()
          local lines_before = H.visible_lines(terminal.buf, terminal.win)

          if session.mux_session then
            if session.backend == "tmux" or session.mux_backend == "tmux" then
              -- submit: https://github.com/folke/sidekick.nvim/blob/41dec4dcdf0c8fe17f5f2e9eeced4645a88afb0d/lua/sidekick/cli/session/tmux.lua#L185-L187
              Util.exec({ "tmux", "send-keys", "-t", session.mux_session, "Enter" })

              vim.defer_fn(function()
                local lines_after = H.visible_lines(terminal.buf, terminal.win)
                if vim.deep_equal(lines_before, lines_after) then
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
                local lines_after = H.visible_lines(terminal.buf, terminal.win)
                if not vim.deep_equal(lines_before, lines_after) and vim.api.nvim_win_is_valid(win) then
                  -- back to original window if <cr> had effect, align with tmux backend behavior
                  vim.api.nvim_set_current_win(win)
                end
              end, 50)
            end, 20)
          end
        end)
      end

      opts = opts or {}

      if vim.bo.filetype == "sidekick_terminal" and vim.fn.mode() ~= "t" then
        vim.cmd.startinsert()
        return
      end

      -- skip the select step if only one terminal visible, regardless of multiple attached sessions
      local visible = H.sidekick.cli.list_visible()
      if #visible == 1 then
        if not (quick and quick ~= visible[1].tool.name) then
          submit(visible[1].terminal, visible[1].session)
          return
        end
      end

      ---@param state sidekick.cli.State
      local function submit_or_focus(state)
        local terminal, session = state.terminal, state.session
        if not (session and terminal and terminal:is_running() and terminal:buf_valid() and terminal:win_valid()) then
          return
        end

        local is_visible = vim.iter(visible):any(function(v)
          return v.win == terminal.win
        end)
        if not is_visible then
          terminal:focus()
          return -- do not submit if terminal was not visible
        end

        submit(terminal, session)
      end

      if quick then
        H.sidekick.cli.quick.with_state(submit_or_focus, quick, {
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
    tools = {
      actions = {
        ---@param keys string[] Keys in neovim format like `<C-u>`
        ---@param fallback? fun(t:sidekick.cli.Terminal) Callback to call if keys have no effect
        ---@return sidekick.cli.Action
        send_keys = function(keys, fallback)
          ---@type sidekick.cli.Action
          return function(t)
            -- for codex/opencode, `vim.b.changedtick` may change without content change
            local lines_before = H.visible_lines(t.buf, t.win)

            local function fb(defer_ms)
              if fallback then
                vim.defer_fn(function()
                  local lines_after = H.visible_lines(t.buf, t.win)
                  if vim.deep_equal(lines_before, lines_after) then
                    fallback(t)
                  end
                end, defer_ms or 50)
              end
            end

            if t.mux_session then
              if t.backend == "tmux" or t.mux_backend == "tmux" then
                local tmux_keys = vim.tbl_map(H.nvim_key_to_tmux, keys)
                require("sidekick.util").exec({ "tmux", "send-keys", "-t", t.mux_session, unpack(tmux_keys) })
                fb()
              else
                -- TODO: zellij
              end
            else
              local win = vim.api.nvim_get_current_win()
              local cursor = vim.api.nvim_win_get_cursor(win)
              local is_norm = vim.fn.mode() ~= "t"
              if is_norm then
                vim.cmd.startinsert()
              end
              vim.api.nvim_feedkeys(vim.keycode(table.concat(keys)), "n", false)
              vim.schedule(function()
                if is_norm then
                  vim.cmd.stopinsert()
                end
                vim.defer_fn(function()
                  vim.api.nvim_win_set_cursor(win, cursor)
                  fb(20)
                end, 10)
              end)
            end
          end
        end,
      },
      opencode = {
        actions = {
          ---@param dir "u"|"d"
          norm_messages_scroll = function(dir)
            ---@type sidekick.cli.Action
            return function(t)
              local count = vim.v.count

              local function vim_scroll()
                vim.cmd("normal! " .. (count > 0 and count or "") .. vim.keycode("<C-" .. dir .. ">"))
              end

              if count > 0 or not t.tool.name:find("opencode") then
                return vim_scroll()
              end

              M.sidekick.cli.tools.actions.send_keys({ "<C-" .. dir .. ">" }, vim_scroll)(t)
            end
          end,
          ---@param edge "top"|"bottom"
          norm_messages_edge = function(edge)
            ---@type sidekick.cli.Action
            return function(t)
              local count = vim.v.count

              local function vim_edge()
                vim.cmd("normal! " .. (count > 0 and count or "") .. (edge == "top" and "gg" or "G"))
              end

              if count > 0 or not t.tool.name:find("opencode") then
                return vim_edge()
              end

              local cursor_lnum = vim.api.nvim_win_get_cursor(t.win)[1]
              local line_count = vim.api.nvim_buf_line_count(t.buf)
              local at_edge = (edge == "top" and cursor_lnum == 1) or (edge == "bottom" and cursor_lnum == line_count)
              if at_edge then
                M.sidekick.cli.tools.actions.send_keys({ edge == "top" and "<Home>" or "<End>" })(t)
              else
                vim_edge()
              end
            end
          end,
        },
      },
    },
  },
}

return M
