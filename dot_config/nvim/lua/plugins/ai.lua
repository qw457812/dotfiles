---@class vim.var_accessor
---@field user_sidekick_indicator? { win: number }

local sidekick_cli_toggle_key = "<M-space>"
local copilot_available = not vim.g.user_is_termux or vim.fn.executable("copilot-language-server") == 1

---@type LazySpec
return {
  -- sidekick cli
  {
    "folke/sidekick.nvim",
    optional = true,
    ---@type sidekick.Config
    opts = {
      cli = {
        ---@type table<string, sidekick.cli.Config|{}>
        tools = {
          claude = {
            cmd = vim.list_extend(vim.fn.executable("command") == 1 and {
              "command", -- ignore ~/.config/fish/functions/claude.fish
              "claude",
            } or { "claude" }, {
              -- "--continue",
              -- "--resume",
              -- "255b938c-0cb9-4858-83a0-6929fa42b927", -- specific session ID
              -- "--fork-session",
            }),
            env = U.ai.claude.provider.plan.anthropic,
          },
        },
      },
    },
  },

  -- HACK: multiple claude/opencode sessions per cwd
  {
    "folke/sidekick.nvim",
    optional = true,
    keys = {
      {
        "<leader>ac",
        function()
          U.ai.sidekick.cli.quick.show("claude" .. (vim.v.count == 0 and "" or vim.v.count))
        end,
        desc = "Claude",
      },
      {
        "<leader>ac",
        function()
          U.ai.sidekick.cli.quick.send("claude" .. (vim.v.count == 0 and "" or vim.v.count), { msg = "{this}" })
        end,
        mode = "x",
        desc = "Claude",
      },
      {
        "<leader>ao",
        function()
          U.ai.sidekick.cli.quick.show("opencode" .. (vim.v.count == 0 and "" or vim.v.count))
        end,
        desc = "OpenCode",
      },
      {
        "<leader>ao",
        function()
          U.ai.sidekick.cli.quick.send("opencode" .. (vim.v.count == 0 and "" or vim.v.count), { msg = "{this}" })
        end,
        mode = "x",
        desc = "OpenCode",
      },
    },
    ---@param opts sidekick.Config
    config = function(_, opts)
      opts.cli = opts.cli or {}
      opts.cli.tools = opts.cli.tools or {}

      local function symlink(target, source)
        if source == "" then
          return
        end
        local to = vim.fs.joinpath(vim.fn.expand("~/.local/bin"), target)
        if not vim.uv.fs_stat(to) then
          vim.uv.fs_symlink(source, to)
        end
      end

      for i = 1, 5 do
        symlink("claude" .. i, vim.fn.exepath("claude")) -- symlink, in favor of `is_proc`
        opts.cli.tools["claude" .. i] = U.extend_tbl(opts.cli.tools.claude, {
          cmd = { "claude" .. i },
          is_proc = "\\<claude" .. i .. "\\>",
        } --[[@as sidekick.cli.Config]])

        symlink("opencode" .. i, vim.fn.exepath("opencode"))
        opts.cli.tools["opencode" .. i] = U.extend_tbl(opts.cli.tools.opencode, {
          cmd = { "opencode" .. i },
          is_proc = "\\<opencode" .. i .. "\\>",
          native_scroll = true,
        } --[[@as sidekick.cli.Config]])
      end

      require("sidekick").setup(opts)
    end,
  },

  {
    "folke/sidekick.nvim",
    optional = true,
    keys = function(_, keys)
      local filter = { installed = true } ---@type sidekick.cli.Filter
      -- stylua: ignore
      return vim.list_extend(keys, {
        { "<c-.>", false, mode = { "n", "x", "i", "t" } },
        { sidekick_cli_toggle_key, function() require("sidekick.cli").toggle({ filter = filter }) end, mode = { "n", "x", "t" }, desc = "Sidekick" },
        { "<c-q>", function() U.ai.sidekick.cli.scrollback({ filter = filter }) end, desc = "Scrollback (Sidekick)" },
        { "<cr>", function() U.ai.sidekick.cli.submit_or_focus({ filter = filter }) end, desc = "Submit or Focus (Sidekick)" },
        { "<cr>", function() require("sidekick.cli").send({ msg = "{this}", filter = filter }) end, mode = "x", desc = "Sidekick" },
        { "<leader>av", false, mode = "x" },
        { "<leader>at", false, mode = { "n", "x" } },
        { "<leader>aa", sidekick_cli_toggle_key, desc = "Sidekick", remap = true },
        { "<leader>aa", function() require("sidekick.cli").send({ msg = "{this}", filter = filter }) end, mode = "x", desc = "Sidekick" },
        { "<leader>as", function() require("sidekick.cli").select({ filter = filter }) end, desc = "Select (Sidekick)" },
        { "<leader>as", function() require("sidekick.cli").send({ msg = "{selection}", filter = filter }) end, mode = "x", desc = "Send (Sidekick)" },
        { "<leader>ad", function() require("sidekick.cli").close() end, desc = "Detach (Sidekick)" },
        { "<leader>ak", U.ai.sidekick.cli.kill, desc = "Kill (Sidekick)" },
        {
          "<leader>ap",
          function()
            require("sidekick.cli").prompt({
              -- add filter
              cb = function(msg)
                if msg then
                  require("sidekick.cli").send({ msg = msg, render = false, filter = filter })
                end
              end,
            })
          end,
          mode = { "n", "x" },
          desc = "Prompt (Sidekick)",
        },
        { "<leader>af", function() require("sidekick.cli").send({ msg = "{file}", filter = filter }) end, desc = "File (Sidekick)" },
        { "<leader>ax", function() U.ai.sidekick.cli.quick.show("codex") end, desc = "Codex" },
        { "<leader>ax", function() U.ai.sidekick.cli.quick.send("codex", { msg = "{this}" }) end, mode = "x", desc = "Codex" },
      })
    end,
    ---@module "sidekick"
    ---@type sidekick.Config
    opts = {
      cli = {
        ---@type sidekick.win.Opts
        win = {
          ---@param terminal sidekick.cli.Terminal
          config = vim.schedule_wrap(function(terminal)
            if terminal:buf_valid() then
              vim.b[terminal.buf].user_lualine_filename = terminal.tool.name
            end

            vim.api.nvim_create_autocmd("FileType", {
              group = vim.api.nvim_create_augroup("sidekick_scrollback", { clear = false }),
              pattern = "sidekick_terminal",
              callback = function(ev)
                local buf = ev.buf
                local sb = terminal.scrollback
                if not (sb and sb.buf == buf) then
                  return
                end

                -- vim.b[buf].sidekick_scrollback = true
                -- vim.b[buf].sidekick_cli = vim.b[buf].sidekick_cli or terminal.tool -- `vim.w.sidekick_cli` does not need this kind of fix, use that instead
                vim.b[buf].user_lualine_filename = vim.b[buf].user_lualine_filename or terminal.tool.name

                if terminal.tool.name:find("claude") then
                  vim.keymap.set("n", "J", function()
                    if vim.fn.search(vim.g.user_is_termux and "^● " or "^⏺ ", "W") == 0 then
                      LazyVim.warn("No more assistant messages", { title = "Sidekick" })
                    end
                  end, { buffer = buf, desc = "Jump to next assistant message (Sidekick)" })
                  vim.keymap.set("n", "K", function()
                    if vim.fn.search(vim.g.user_is_termux and "^● " or "^⏺ ", "Wb") == 0 then
                      LazyVim.warn("No more assistant messages", { title = "Sidekick" })
                    end
                  end, { buffer = buf, desc = "Jump to previous assistant message (Sidekick)" })

                  -- schedule to overwrite `]]` and `[[` defined in https://github.com/neovim/neovim/blob/520568f40f22d77e623ddda77cf751031774384b/runtime/lua/vim/_defaults.lua#L651-L656
                  vim.schedule(function()
                    if not vim.api.nvim_buf_is_valid(buf) then
                      return
                    end

                    -- jump to input/select prompt, save some `k` presses
                    if vim.api.nvim_get_current_buf() == buf then
                      vim.fn.search("❯", "Wb")
                    end

                    vim.keymap.set("n", "]]", function()
                      if vim.fn.search("^❯ ", "W") == 0 then
                        LazyVim.warn("No more user messages", { title = "Sidekick" })
                      end
                    end, { buffer = buf, desc = "Jump to next user message (Sidekick)" })
                    vim.keymap.set("n", "[[", function()
                      if vim.fn.search("^❯ ", "Wb") == 0 then
                        LazyVim.warn("No more user messages", { title = "Sidekick" })
                      end
                    end, { buffer = buf, desc = "Jump to previous user message (Sidekick)" })
                  end)
                end
              end,
            })
          end),
          layout = vim.g.user_is_termux and "float" or "right", ---@type "float"|"left"|"bottom"|"top"|"right"
          ---@type vim.api.keyset.win_config
          float = {
            row = 0,
            col = 0,
            width = vim.o.columns,
            height = vim.o.lines - 3, -- see: U.snacks.win.fullscreen_height
          },
          ---@type vim.api.keyset.win_config
          split = {
            width = math.max(80, math.floor(vim.o.columns * 0.5)),
            height = math.max(20, math.floor(vim.o.lines * 0.5)),
          },
          ---@type table<string, sidekick.cli.Keymap|false|nil>
          keys = {
            hide_ctrl_dot = false,
            hide_toggle_key = { sidekick_cli_toggle_key, "hide", mode = "nt" },
            down_ctrl_j = not vim.g.user_is_termux and { "<c-j>", "<Down>" } or false, -- this overrides the window navigation
            up_ctrl_k = not vim.g.user_is_termux and { "<c-k>", "<Up>" } or false, -- this overrides the window navigation
            -- down_ctrl_n = { "<c-n>", "<Down>" },
            -- up_ctrl_p = { "<c-p>", "<Up>" },
            -- prompt = { "<a-p>", "prompt" }, -- claude code uses <a-p> for its own functionality
            -- buffers = { "<a-b>", "buffers", mode = "nt" },
            -- files = { "<a-f>", "files", mode = "nt" },
            blur_t = { "<c-o>", "blur" },
            blur_n = { "<c-o>", "blur", mode = "n" },
            -- blur_esc = {
            --   "<esc>",
            --   function(t)
            --     if not U.keymap.clear_ui_esc() then
            --       t:blur()
            --     end
            --   end,
            --   desc = "Clear UI or Blur",
            --   mode = "n",
            -- },
            term_enter = {
              "<esc>",
              function()
                if not U.keymap.clear_ui_esc() then
                  vim.cmd.startinsert()
                end
              end,
              desc = "Clear UI or Enter Terminal Mode",
              mode = "n",
            },
            newline = {
              "<S-CR>",
              function(t)
                t:send("\n")
              end,
            },
            -- we already have global mappings for window navigation (plugins.extras.util.tmux)
            nav_down = vim.F.if_nil(vim.g.neovide, false) and nil, -- HACK: fix "'kitty @ kitten neighboring_window.py right' returned 1", same for nav_up and nav_right
            nav_up = vim.F.if_nil(vim.g.neovide, false) and nil,
            nav_right = vim.F.if_nil(vim.g.neovide, false) and nil,
            nav_left = vim.F.if_nil(vim.g.neovide, false) and nil, -- not necessary, but for consistency
            editor_open = {
              "<C-g>",
              function(t)
                local name = t.tool.name
                if name:find("claude") or name:find("opencode") or name:find("codex") then
                  U.ai.sidekick.cli.tools.actions.send_keys({ "<C-g>" })(t)
                  vim.cmd.startinsert()
                else
                  vim.api.nvim_feedkeys(vim.keycode("<C-g>"), "n", false)
                end
              end,
              mode = "n",
            },
          },
        },
        ---@type sidekick.cli.Mux
        mux = {
          enabled = true,
        },
        ---@type table<string, sidekick.cli.Config|{}>
        tools = {
          claude = {
            env = {
              __IS_CLAUDECODE_NVIM = "1", -- flag to disable claude code statusline in ~/.claude/settings.json
              NVIM_FLATTEN_NEST = "1", -- allow ctrl-g to edit prompt in nvim" to be nested for flatten.nvim
            },
            keys = {
              blur_t = false, -- claude code uses <c-o> for its own functionality
              ultrathink = {
                "<a-u>",
                function(t)
                  t:send(" ultrathink ")
                end,
              },
            },
          },
          codex = { cmd = { "codex" } },
          opencode = {
            env = {
              NVIM_FLATTEN_NEST = "1",
            },
            keys = {
              prompt = false, -- opencode uses <c-p> for its own functionality
              -- up_ctrl_p = false, -- opencode uses <c-p> for its own functionality
            },
          },
          -- HACK: disable some installed tools
          copilot = { cmd = { "hack_to_disable_copilot" } },
          gemini = { cmd = { "hack_to_disable_gemini" } },
          aider = { cmd = { "hack_to_disable_aider" } },
          -- debug = { cmd = { "bash", "-c", "env | sort | bat -l env" } },
        },
        ---@type table<string, sidekick.Prompt|string|fun(ctx:sidekick.context.ctx):(string?)>
        prompts = {
          refactor = "Please refactor {this} to be more maintainable",
          security = "Review {file} for security vulnerabilities",
          commit = "Commit only the staged changes",
          review_staged = "Review only the staged changes",
          review_unstaged = "Review only the unstaged changes",
        },
      },
      ui = {
        icons = {
          installed = "󰒲 ", -- 󰞃 󰯡
        },
      },
    },
    specs = {
      {
        "folke/snacks.nvim",
        optional = true,
        ---@module "snacks"
        ---@type snacks.Config
        opts = {
          picker = {
            sources = {
              select = {
                ---@type table<string, snacks.picker.Config|{}>
                kinds = {
                  -- https://github.com/folke/sidekick.nvim/blob/756882545e4fcb50185e3089ee77a67706951139/lua/sidekick/cli/ui/select.lua#L46
                  sidekick_cli = {
                    win = {
                      input = {
                        keys = {
                          [sidekick_cli_toggle_key] = { "close", mode = { "i", "n" }, desc = "Close (Sidekick)" },
                        },
                      },
                    },
                  },
                  -- https://github.com/folke/sidekick.nvim/blob/756882545e4fcb50185e3089ee77a67706951139/lua/sidekick/cli/ui/prompt.lua#L108
                  sidekick_prompt = {
                    layout = {
                      preset = function()
                        local layouts = { "vscode", "narrow" }
                        return layouts[math.random(#layouts)]
                      end,
                    },
                    win = {
                      input = {
                        keys = {
                          ["<c-y>"] = false,
                          ["y"] = false,
                          ["<localleader>y"] = { "yank" },
                        },
                      },
                    },
                  },
                },
              },
            },
          },
        },
      },
    },
  },

  {
    "folke/sidekick.nvim",
    optional = true,
    opts = function()
      local Terminal = require("sidekick.cli.terminal")

      -- HACK: resize window after opening sidekick terminal (split)
      -- see: https://github.com/folke/sidekick.nvim/pull/203
      -- https://github.com/folke/sidekick.nvim/blob/83b6815c0ed738576f101aad31c79b885c892e0f/lua/sidekick/cli/terminal.lua#L340-L378
      ---@param self sidekick.cli.Terminal
      Terminal.open_win = U.patch_func(Terminal.open_win, function(orig, self)
        local ret = orig(self)
        if self.opts.layout ~= "float" then
          vim.cmd("wincmd =")
        end
        return ret
      end)

      -- opencode does not have scrollback since its `native_scroll` is `true`
      vim.api.nvim_create_autocmd("FileType", {
        group = vim.api.nvim_create_augroup("sidekick_opencode_norm", { clear = false }),
        pattern = "sidekick_terminal",
        -- schedule_wrap since `vim.w.sidekick_cli` and `vim.w.sidekick_session_id` is set after `vim.bo.filetype`
        -- see: https://github.com/folke/sidekick.nvim/blob/83b6815c0ed738576f101aad31c79b885c892e0f/lua/sidekick/cli/terminal.lua#L153-L157
        ---@param ev vim.api.keyset.create_autocmd.callback_args
        callback = vim.schedule_wrap(function(ev)
          local buf = ev.buf
          if not vim.api.nvim_buf_is_valid(buf) then
            return
          end
          local win = vim.fn.bufwinid(buf)
          if win == -1 then
            return
          end
          local tool = assert(vim.w[win].sidekick_cli)
          local session_id = assert(vim.w[win].sidekick_session_id)
          local terminal = assert(Terminal.get(session_id))
          -- TODO: claude code without mux enabled also needs keymaps created here
          if not tool.name:find("opencode") then
            return
          end

          -- putting opencode keymaps in `opts.cli.tools.opencode.keys` causes errors, related to `mode = "n"`
          -- putting opencode keymaps in `opts.cli.win.keys` needs fallbacks for other tools
          U.keymap("n", { "<C-u>", "u" }, function()
            U.ai.sidekick.cli.tools.opencode.actions.norm_messages_scroll("u")(terminal)
          end, { buffer = buf, desc = "Messages Scroll Up (Sidekick)" })
          U.keymap("n", { "<C-d>", "d" }, function()
            U.ai.sidekick.cli.tools.opencode.actions.norm_messages_scroll("d")(terminal)
          end, { buffer = buf, desc = "Messages Scroll Down (Sidekick)" })

          vim.keymap.set("n", "gg", function()
            U.ai.sidekick.cli.tools.opencode.actions.norm_messages_edge("top")(terminal)
          end, { buffer = buf, desc = "Go to top, or first message (Sidekick)" })
          vim.keymap.set("n", "G", function()
            U.ai.sidekick.cli.tools.opencode.actions.norm_messages_edge("bottom")(terminal)
          end, { buffer = buf, desc = "Go to bottom, or last message (Sidekick)" })

          -- schedule is needed to overwrite `]]` and `[[` defined in https://github.com/neovim/neovim/blob/520568f40f22d77e623ddda77cf751031774384b/runtime/lua/vim/_defaults.lua#L651-L656
          vim.keymap.set("n", "]]", function()
            U.ai.sidekick.cli.tools.actions.send_keys({ "<A-j>" })(terminal)
          end, { buffer = buf, desc = "Jump to next user message (Sidekick)" })
          vim.keymap.set("n", "[[", function()
            U.ai.sidekick.cli.tools.actions.send_keys({ "<A-k>" })(terminal)
          end, { buffer = buf, desc = "Jump to previous user message (Sidekick)" })

          -- TODO: more useful keymaps: https://opencode.ai/docs/keybinds/
        end),
      })

      Snacks.util.set_hl({
        SidekickCliInstalled = "Comment",
        SidekickCliIndicatorTerminal = "lualine_c_filename_terminal",
        SidekickCliIndicatorScrollback = { fg = "#FF007C", bold = true },
      })

      -- shown indicator when the sidekick window is focused
      -- https://github.com/folke/snacks.nvim/blob/3c2d79162f8174d5e1c33539a72025a25f4af590/lua/snacks/zen.lua#L69-L80
      Snacks.config.style("sidekick_indicator", {
        text = function()
          return ("▍ %s    "):format((vim.w.sidekick_cli or {}).name or "sidekick")
        end,
        minimal = true,
        enter = false,
        focusable = false,
        height = 1,
        relative = "win",
        zindex = 51, -- sidekick_terminal + 1
        row = 0, -- 1
        col = -1,
        backdrop = false,
        bo = { filetype = "sidekick_indicator" },
      })

      -- https://github.com/folke/snacks.nvim/blob/3c2d79162f8174d5e1c33539a72025a25f4af590/lua/snacks/zen.lua#L160-L204
      local indicator_group = vim.api.nvim_create_augroup("sidekick_indicator", { clear = true })
      vim.api.nvim_create_autocmd("WinEnter", {
        group = indicator_group,
        callback = function()
          local win = vim.api.nvim_get_current_win()
          if not vim.w[win].sidekick_cli then
            return
          end
          if vim.w[win].user_sidekick_indicator then
            return -- already shown (likely not needed, but kept as a safeguard)
          end

          local indicator = Snacks.win({ show = false, style = "sidekick_indicator" })
          ---@diagnostic disable-next-line: invisible
          indicator:open_buf()
          local lines = vim.api.nvim_buf_get_lines(indicator.buf, 0, -1, false)
          indicator.opts.width = vim.api.nvim_strwidth(lines[1] or "")
          indicator:show()
          vim.w[win].user_sidekick_indicator = { win = indicator.win }

          ---@param w number
          ---@param is_sb boolean
          local function winhl(w, is_sb)
            local hl = is_sb and "SidekickCliIndicatorScrollback" or "SidekickCliIndicatorTerminal"
            vim.wo[w][0].winhighlight = "NormalFloat:" .. hl
          end

          -- schedule for vim.fn.mode()
          vim.schedule(function()
            if indicator:win_valid() then
              winhl(indicator.win, vim.fn.mode() ~= "t")
            end
          end)
          indicator:on("TermEnter", function(self)
            if vim.w.sidekick_cli and self:win_valid() then
              winhl(self.win, false)
            end
          end)
          indicator:on("TermLeave", function(self)
            if vim.w.sidekick_cli and self:win_valid() then
              winhl(self.win, true)
            end
          end)
        end,
      })

      vim.api.nvim_create_autocmd("WinLeave", {
        group = indicator_group,
        callback = function()
          if not vim.w.sidekick_cli then
            return
          end
          local indicator = vim.w.user_sidekick_indicator
          if indicator then
            vim.w.user_sidekick_indicator = nil
            vim.api.nvim_win_close(indicator.win, false)
          end
        end,
      })
    end,
  },

  -- TODO: duplicate code with shell-command-editor.lua
  {
    "LazyVim/LazyVim",
    opts = function()
      local tmpdir = (vim.env.TMPDIR or "/tmp"):gsub("/$", "")
      vim.api.nvim_create_autocmd("BufRead", {
        group = vim.api.nvim_create_augroup("ai_cli_prompt", { clear = true }),
        pattern = {
          tmpdir .. "/claude-prompt-*.md", -- claude code
          tmpdir .. "/[0-9]*.md", -- https://github.com/sst/opencode/blob/041353f4ff992e7be4455eaf6e71f492a97a123f/packages/opencode/src/cli/cmd/tui/util/editor.ts#L12
          tmpdir .. "/.*.md", -- https://github.com/openai/codex/blob/f6b563ec6403392aadbc31f449226aaabd881c01/codex-rs/tui/src/external_editor.rs#L60
        },
        once = true,
        callback = function(ev)
          vim.opt_local.wrap = true
          vim.diagnostic.enable(false, { bufnr = ev.buf })

          -- HACK: Fix for https://github.com/anthropics/claude-code/issues/10375
          if ev.match:match("claude%-prompt") then
            -- Disable focus reporting mode when leaving Neovim to prevent [I and [O escape sequences
            -- from leaking into Claude Code
            vim.api.nvim_create_autocmd("VimLeavePre", {
              callback = function()
                if vim.g.user_is_tmux then
                  io.stdout:write("\x1bPtmux;\x1b\x1b[?1004l\x1b\\")
                else
                  -- io.stdout:write("\x1b[?1004l") -- FIXME: not working
                end
              end,
            })

            -- -- Remove "[O" and "[I" for claude code prompts, but keep the "[Image #1]"
            -- vim.api.nvim_buf_call(
            --   ev.buf,
            --   vim.schedule_wrap(function()
            --     vim.cmd([[%s/\[O//ge]])
            --     vim.cmd([[%s/\[I\ze\(mage\)\@!//ge]]) -- match `[I` only when it's NOT followed by 'mage'
            --     if vim.bo[ev.buf].modified then
            --       vim.cmd("silent! noautocmd lockmarks write")
            --     end
            --   end)
            -- )
          end

          vim.keymap.set("n", "<Esc>", function()
            if not U.keymap.clear_ui_esc() then
              vim.cmd([[quitall]])
            end
          end, { buffer = ev.buf, desc = "Clear UI or Exit" })

          vim.keymap.set({ "n", "i" }, "<C-s>", function()
            vim.cmd([[wqa]])
          end, { buffer = ev.buf, desc = "Save and Exit" })

          vim.api.nvim_create_autocmd({ "InsertLeave", "TextChanged" }, {
            group = vim.api.nvim_create_augroup("ai_cli_prompt_autowrite", { clear = true }),
            buffer = ev.buf,
            callback = function()
              vim.api.nvim_buf_call(ev.buf, function()
                vim.cmd("silent! noautocmd lockmarks write")
              end)
            end,
          })
        end,
      })

      vim.api.nvim_create_autocmd("FileType", {
        pattern = "markdown",
        callback = function(ev)
          local path = vim.api.nvim_buf_get_name(ev.buf)
          if
            path:match("/CLAUDE%.md$")
            or path:match("/CLAUDE%.local%.md$")
            or path:match("/AGENTS%.md$")
            or path:find("/%.claude/rules/")
          then
            vim.diagnostic.enable(false, { bufnr = ev.buf })
          end
        end,
      })
    end,
  },

  -- sidekick nes
  {
    "folke/sidekick.nvim",
    optional = true,
    event = "LazyFile",
    keys = function(_, keys)
      if vim.g.user_distinguish_ctrl_i_tab or vim.g.user_is_termux then
        table.insert(keys, {
          "<tab>",
          LazyVim.cmp.map({ "ai_nes" }, function()
            vim.cmd("wincmd w")
          end),
          desc = "Jump/Apply Next Edit Suggestions or Next Window (Sidekick)",
        })
      end
      return keys
    end,
    ---@param opts sidekick.Config
    opts = function(_, opts)
      if copilot_available then
        U.toggle.ai_cmps.sidekick_nes = Snacks.toggle({
          name = "Sidekick NES",
          get = function()
            return require("sidekick.nes").enabled
          end,
          set = function(state)
            require("sidekick.nes").enable(state)
          end,
        })
      else
        opts.nes = opts.nes or {}
        opts.nes.enabled = false
      end

      return U.extend_tbl(opts, {
        nes = {
          clear = {
            esc = false, -- handled by U.keymap.clear_ui_esc()
          },
        },
      } --[[@as sidekick.Config]])
    end,
    specs = {
      copilot_available and vim.g.ai_cmp and not LazyVim.has_extra("ai.copilot") and {
        "saghen/blink.cmp",
        optional = true,
        dependencies = "fang2hou/blink-copilot",
        opts = {
          sources = {
            default = { "copilot" },
            providers = {
              copilot = {
                module = "blink-copilot",
                score_offset = 100,
                async = true,
              },
            },
          },
        },
      } or { import = "foobar", enabled = false }, -- dummy import
    },
  },

  {
    "neovim/nvim-lspconfig",
    ---@param opts PluginLspOpts
    opts = function(_, opts)
      local servers = opts.servers
      if servers.copilot then
        servers.copilot = servers.copilot == true and {} or servers.copilot
        if vim.g.user_is_termux then
          -- latest version of copilot-language-server failed to start on termux
          -- using `npm install -g @github/copilot-language-server@1.380.0`
          -- tested `copilot-language-server --version` without errors
          servers.copilot.mason = false
        end
        servers.copilot.root_dir = function(bufnr, on_dir)
          local root = LazyVim.root({ buf = bufnr })
          on_dir(root ~= vim.uv.cwd() and root or vim.fs.root(bufnr, vim.lsp.config.copilot.root_markers))
        end

        if servers.copilot.enabled ~= false then
          U.toggle.ai_cmps.copilot = Snacks.toggle({
            name = "copilot-language-server",
            get = function()
              return vim.lsp.is_enabled("copilot")
            end,
            set = function(state)
              vim.lsp.enable("copilot", state)
            end,
          })
        end
      end
    end,
  },

  -- ===========================================================================
  -- ALL LAZY SPECS BELOW ARE UNUSED
  -- ===========================================================================

  {
    "zbirenbaum/copilot.lua",
    optional = true,
    opts = {
      root_dir = function()
        return LazyVim.root()
      end,
      filetypes = { ["*"] = true },
    },
  },
  {
    "zbirenbaum/copilot.lua",
    optional = true,
    opts = function()
      U.toggle.ai_cmps.copilot_lua = Snacks.toggle({
        name = "copilot.lua",
        get = function()
          return not require("copilot.client").is_disabled()
        end,
        set = function(state)
          if state then
            require("copilot.command").enable()
          else
            require("copilot.command").disable()
          end
        end,
      })
    end,
  },

  {
    "Exafunction/codeium.nvim",
    optional = true,
    opts = function()
      local Source = require("codeium.source")

      U.toggle.ai_cmps.codeium = Snacks.toggle({
        name = "Codeium",
        get = function()
          return not vim.g.user_codeium_disable
        end,
        set = function(state)
          vim.g.user_codeium_disable = not state
        end,
      })

      -- HACK: toggle, see: https://github.com/Exafunction/codeium.nvim/issues/136#issuecomment-2127891793
      Source.is_available = U.patch_func(Source.is_available, function(orig, self)
        return not vim.g.user_codeium_disable and orig(self)
      end)
    end,
    specs = {
      {
        "nvim-cmp",
        optional = true,
        opts = function(_, opts)
          for _, source in ipairs(opts.sources or {}) do
            if source.name == "codeium" then
              source.priority = 99 -- lower than copilot
              break
            end
          end
        end,
      },
      {
        "saghen/blink.cmp",
        optional = true,
        opts = function(_, opts)
          if vim.tbl_get(opts, "sources", "providers", "codeium", "score_offset") then
            opts.sources.providers.codeium.score_offset = 99 -- lower than copilot
          end
        end,
      },
      {
        "folke/noice.nvim",
        optional = true,
        opts = function(_, opts)
          opts.routes = vim.list_extend(opts.routes or {}, {
            {
              filter = {
                event = "msg_show",
                find = "^%[codeium/codeium%] ",
              },
              opts = { skip = true },
            },
            {
              filter = {
                event = "notify",
                find = "^completion request failed$",
              },
              opts = { skip = true },
            },
          })
        end,
      },
    },
  },

  {
    "CopilotC-Nvim/CopilotChat.nvim",
    optional = true,
    cmd = { "CopilotChatModels", "CopilotChatPrompts" },
    dependencies = {
      { "MeanderingProgrammer/render-markdown.nvim", optional = true, ft = "copilot-chat" },
    },
    -- stylua: ignore
    keys = {
      { "<leader>aa", mode = { "n", "x" }, false },
      { "<leader>ax", mode = { "n", "x" }, false },
      { "<leader>ap", mode = { "n", "x" }, false },
      { "<leader>aq", mode = { "n", "x" }, false },
      {
        "<leader>app",
        mode = { "n", "x" },
        function()
          local copilot_chat = require("CopilotChat")
          copilot_chat.open()

          -- copied from: https://github.com/CopilotC-Nvim/CopilotChat.nvim/blob/294bcb620ff66183e142cd8a43a7c77d5bc77a16/lua/CopilotChat/ui/chat.lua#L366-L375
          local chat = copilot_chat.chat
          if chat:focused() and vim.bo[chat.bufnr].modifiable then
            vim.cmd("startinsert!") -- add `!`
          end
        end,
        desc = "Chat",
      },
      { "<leader>apa", function() require("CopilotChat").select_prompt() end, desc = "Prompt Actions", mode = { "n", "x" } },
      { "<localleader>c", function() require("CopilotChat").reset() end, desc = "Clear", mode = { "n", "x" }, ft = "copilot-chat" },
      { "<localleader>m", "<cmd>CopilotChatModels<cr>", desc = "Switch Model", ft = "copilot-chat" },
      { "<localleader>s", "<cmd>CopilotChatStop<cr>", desc = "Stop", ft = "copilot-chat" },
    },
    opts = function(_, opts)
      vim.api.nvim_create_autocmd("FileType", {
        pattern = "copilot-chat",
        callback = function(ev)
          -- see: https://github.com/LazyVim/LazyVim/pull/5754
          -- path sources triggered by "/" interfere with CopilotChat commands
          vim.b[ev.buf].user_blink_path = false

          vim.keymap.set(
            "n",
            "<Esc>",
            U.keymap.clear_ui_or_unfocus_esc,
            { buffer = ev.buf, desc = "Clear UI or Unfocus (CopilotChat)" }
          )
        end,
      })

      return U.extend_tbl(opts, {
        -- model = "claude-sonnet-4.5",
        -- show_help = false,
        language = "Chinese",
        -- stylua: ignore
        mappings = {
          reset            = { normal = "<localleader>c"  },
          toggle_sticky    = { normal = "<localleader>p"  },
          clear_stickies   = { normal = "<localleader>x"  },
          accept_diff      = { normal = "<localleader>a"  },
          jump_to_diff     = { normal = "<localleader>j"  },
          quickfix_answers = { normal = "<localleader>qa" },
          quickfix_diffs   = { normal = "<localleader>qd" },
          yank_diff        = { normal = "<localleader>y"  },
          show_diff        = { normal = "<localleader>d"  },
          show_info        = { normal = "<localleader>i"  },
          show_help        = { normal = "g?"              },
        },
        headers = {
          user = "##   User ",
          assistant = "##   Copilot ",
          tool = "## 󱁤  Tool ",
        },
        window = {
          layout = function()
            return vim.o.columns >= 120 and "vertical" or "horizontal"
          end,
        },
      } --[[@as CopilotChat.config.Config]])
    end,
    specs = {
      {
        "folke/which-key.nvim",
        opts = {
          spec = {
            {
              mode = { "n", "x" },
              { "<leader>ap", group = "copilot" },
            },
          },
        },
      },
      {
        "folke/edgy.nvim",
        optional = true,
        opts = function(_, opts)
          if vim.o.columns >= 120 then
            return
          end
          opts.right = opts.right or {}
          local copilot_chat_view
          for i, view in ipairs(opts.right) do
            if view.ft == "copilot-chat" then
              copilot_chat_view = table.remove(opts.right, i)
              break
            end
          end
          if copilot_chat_view then
            opts.bottom = opts.bottom or {}
            copilot_chat_view.size = { height = 0.4 }
            table.insert(opts.bottom, copilot_chat_view)
          end
        end,
      },
    },
  },
}
