local sidekick_cli_toggle_key = "<M-space>"
local copilot_available = not vim.g.user_is_termux -- copilot-language-server failed to start on termux

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
              -- "--fork-session",
            }),
            env = U.ai.claude.provider.plan.anthropic,
          },
        },
      },
    },
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
        { "<leader>ac", function() require("sidekick.cli").toggle({ name = "claude" }) end, desc = "Claude" },
        { "<leader>ac", function() require("sidekick.cli").send({ msg = "{this}", filter = { name = "claude" } }) end, mode = "x", desc = "Claude" },
        { "<leader>ax", function() require("sidekick.cli").toggle({ name = "codex" }) end, desc = "Codex" },
        { "<leader>ax", function() require("sidekick.cli").send({ msg = "{this}", filter = { name = "codex" } }) end, mode = "x", desc = "Codex" },
        { "<leader>ao", function() require("sidekick.cli").toggle({ name = "opencode" }) end, desc = "OpenCode" },
        { "<leader>ao", function() require("sidekick.cli").send({ msg = "{this}", filter = { name = "opencode" } }) end, mode = "x", desc = "OpenCode" },
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

                vim.b[buf].user_lualine_filename = vim.b[buf].user_lualine_filename or terminal.tool.name

                if terminal.tool.name == "claude" then
                  local function goto_input_prompt()
                    local lnum = vim.fn.search("^> ", "Wb") -- inputting
                    lnum = lnum == 0 and vim.fn.search(" ❯ ", "Wb") or lnum -- selecting like `/config`
                  end

                  -- schedule to overwrite `]]` and `[[` defined in https://github.com/neovim/neovim/blob/520568f40f22d77e623ddda77cf751031774384b/runtime/lua/vim/_defaults.lua#L651-L656
                  vim.schedule(function()
                    if not vim.api.nvim_buf_is_valid(buf) then
                      return
                    end

                    goto_input_prompt() -- save some `k` presses

                    vim.keymap.set("n", "]]", function()
                      local lnum = vim.fn.search("^> ", "W")
                      if lnum == 0 then
                        LazyVim.warn("No more user messages", { title = "Sidekick" })
                      end
                    end, { buffer = buf, desc = "Jump to next user message (Sidekick)" })
                    vim.keymap.set("n", "[[", function()
                      local lnum = vim.fn.search("^> ", "Wb")
                      if lnum == 0 then
                        LazyVim.warn("No more user messages", { title = "Sidekick" })
                      end
                    end, { buffer = buf, desc = "Jump to previous user message (Sidekick)" })
                  end)
                end
              end,
            })
          end),
          layout = vim.g.user_is_termux and "bottom" or "right", ---@type "float"|"left"|"bottom"|"top"|"right"
          ---@type vim.api.keyset.win_config
          float = {
            width = 1,
            height = vim.o.lines - 4, -- see: U.snacks.win.fullscreen_height
          },
          ---@type vim.api.keyset.win_config
          split = {
            width = math.max(80, math.floor(vim.o.columns * 0.5)),
            height = math.max(20, math.floor(vim.o.lines * 0.5)),
          },
          ---@type table<string, sidekick.cli.Keymap|false>
          keys = {
            hide_ctrl_dot = false,
            hide_toggle_key = { sidekick_cli_toggle_key, "hide", mode = "nt" },
            down_ctrl_j = not vim.g.user_is_termux and { "<c-j>", "<Down>" } or false, -- this overrides the window navigation
            up_ctrl_k = not vim.g.user_is_termux and { "<c-k>", "<Up>" } or false, -- this overrides the window navigation
            down_ctrl_n = { "<c-n>", "<Down>" },
            up_ctrl_p = { "<c-p>", "<Up>" },
            prompt = { "<a-p>", "prompt" },
            buffers = { "<a-b>", "buffers", mode = "nt" },
            files = { "<a-f>", "files", mode = "nt" },
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
            nav_down = false, -- HACK: fix "'kitty @ kitten neighboring_window.py right' returned 1", same for nav_up and nav_right
            nav_up = false,
            nav_right = false,
            nav_left = false, -- not necessary, but for consistency
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
              up_ctrl_p = false, -- opencode uses <c-p> for its own functionality
            },
          },
          -- HACK: disable some installed tools
          copilot = { cmd = tonumber(os.date("%d")) < 20 and { "hack_to_disable_copilot" } or { "copilot" } },
          gemini = { cmd = { "hack_to_disable_gemini" } },
          aider = { cmd = { "hack_to_disable_aider" } },
          -- debug = { cmd = { "bash", "-c", "env | sort | bat -l env" } },
        },
        ---@type table<string, sidekick.Prompt|string|fun(ctx:sidekick.context.ctx):(string?)>
        prompts = {
          refactor = "Please refactor {this} to be more maintainable",
          security = "Review {file} for security vulnerabilities",
          commit = "Commit only the staged changes",
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
    ---@param opts sidekick.Config
    opts = function(_, opts)
      local Terminal = require("sidekick.cli.terminal")

      -- HACK: with tmux as backend, JAVA_HOME differs in sidekick cli for unknown reasons, check `! mvn -v`
      if vim.tbl_get(opts, "cli", "mux", "enabled") then
        for _, tool in pairs(opts.cli.tools or {}) do
          tool.env = U.extend_tbl({ JAVA_HOME = vim.env.JAVA_HOME }, tool.env)
        end
      end

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

      Snacks.util.set_hl({
        SidekickCliIndicatorTerminal = "lualine_c_filename_terminal",
        SidekickCliIndicatorScrollback = { fg = "#FF007C", bold = true },
        SidekickCliInstalled = "Comment",
      })

      -- shown indicator when the sidekick window is focused
      -- https://github.com/folke/snacks.nvim/blob/3c2d79162f8174d5e1c33539a72025a25f4af590/lua/snacks/zen.lua#L69-L80
      Snacks.config.style("sidekick_indicator", {
        text = "▍ sidekick    ",
        minimal = true,
        enter = false,
        focusable = false,
        height = 1,
        row = 0,
        col = -1,
        backdrop = false,
        bo = { filetype = "sidekick_indicator" },
      })

      -- https://github.com/folke/snacks.nvim/blob/3c2d79162f8174d5e1c33539a72025a25f4af590/lua/snacks/zen.lua#L160-L204
      local indicator ---@type snacks.win?
      vim.api.nvim_create_autocmd("BufEnter", {
        group = vim.api.nvim_create_augroup("sidekick_indicator", { clear = true }),
        callback = function(ev)
          if vim.bo[ev.buf].filetype ~= "sidekick_terminal" then
            return
          end
          if not indicator then
            local hl = ev.match == "" and "SidekickCliIndicatorScrollback" or "SidekickCliIndicatorTerminal"
            indicator = Snacks.win({
              show = false,
              style = "sidekick_indicator",
              wo = { winhighlight = "NormalFloat:" .. hl },
            })
            ---@diagnostic disable-next-line: invisible
            indicator:open_buf()
            local lines = vim.api.nvim_buf_get_lines(indicator.buf, 0, -1, false)
            indicator.opts.width = vim.api.nvim_strwidth(lines[1] or "")
            indicator:show()
          end
          vim.api.nvim_create_autocmd("BufLeave", {
            group = vim.api.nvim_create_augroup("sidekick_indicator_" .. ev.buf, { clear = true }),
            buffer = ev.buf,
            callback = function()
              if indicator then
                indicator:close()
                indicator = nil
              end
            end,
          })
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
