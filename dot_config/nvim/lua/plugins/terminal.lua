---@type LazySpec
return {
  {
    "folke/snacks.nvim",
    keys = function(_, keys)
      local function ctrl_slash()
        local git_root = (U.is_file() or not vim.g.user_last_file) and Snacks.git.get_root()
          or Snacks.git.get_root(vim.g.user_last_file.path)

        Snacks.terminal(nil, {
          win = {
            keys = {
              hide_ctrl_slash = { "<c-/>", "hide", desc = "Hide Terminal", mode = { "n", "t" } },
              hide_ctrl_underscore = { "<c-_>", "hide", desc = "which_key_ignore", mode = { "n", "t" } },
            },
          },
          cwd = git_root,
          -- make sure win.position is bottom, without this, type <c-space> first then <c-/> will make the terminal float
          -- see: https://github.com/folke/snacks.nvim/blob/544a2ae01c28056629a0c90f8d0ff40995c84e42/lua/snacks/terminal.lua#L174
          env = { __NVIM_SNACKS_TERMINAL_ID = "CTRL-/" },
        })
      end

      return vim.list_extend(keys, {
        -- stylua: ignore
        { "<leader>fT", function() U.terminal() end, desc = "Terminal (cwd)" },
        -- { "<leader>ft", function() U.terminal(nil, { cwd = LazyVim.root() }) end, desc = "Terminal (Root Dir)" },
        {
          "<c-space>",
          function()
            -- fallback to last file buffer's root if current buffer is not a file
            local root = (U.is_file() or not vim.g.user_last_file) and LazyVim.root() or vim.g.user_last_file.root

            -- TODO: focus if terminal is already open but not focused
            Snacks.terminal(nil, {
              win = {
                position = "float",
                height = vim.g.user_is_termux and U.snacks.win.fullscreen_height or nil,
                width = vim.g.user_is_termux and 0 or nil,
                keys = {
                  hide_ctrl_space = { "<c-space>", "hide", mode = { "n", "t" } },
                },
              },
              cwd = root,
            })
          end,
          desc = "Float Terminal (Root Dir)",
          mode = { "n", "t" },
        },
        { "<c-/>", ctrl_slash, desc = "Terminal (Git Root Dir)" },
        { "<c-_>", ctrl_slash, desc = "which_key_ignore" }, -- NOTE: type `<C-v><C-/>` in insert mode to see what your terminal sends, `<C-/>` or `<C-_>`
        {
          "<c-,>",
          function()
            local filepath = vim.fn.expand("%:p:h")
            filepath = vim.fn.isdirectory(filepath) == 1 and filepath
              or (vim.g.user_last_file and vim.fn.fnamemodify(vim.g.user_last_file.path, ":h"))
              or LazyVim.root()

            Snacks.terminal(nil, {
              win = {
                keys = {
                  hide_ctrl_comma = { "<c-,>", "hide", mode = { "n", "t" } },
                },
              },
              cwd = filepath,
            })
          end,
          desc = "Terminal (Buffer Dir)",
          mode = { "n", "t" },
        },
      })
    end,
    ---@module "snacks"
    ---@type snacks.Config
    opts = {
      terminal = {
        win = {
          -- position = "float", -- alternative: style = "float"
          actions = {
            blur = function(self)
              if not self:valid() then
                return
              end
              if self:is_floating() then
                self:hide()
              elseif vim.api.nvim_get_current_win() == self.win then
                vim.cmd.wincmd("p")
                if vim.api.nvim_get_current_win() == self.win then
                  vim.cmd.wincmd("w")
                end
              end
            end,
          },
          keys = {
            -- Disable `<c-/>` to avoid conflicts with fish/claude undo.
            -- Instead, `<c-/>` only hides the terminal opened by `<c-/>` (see `hide_ctrl_slash` above)
            hide_slash = false,
            hide_underscore = false,
            t_c_o = { "<c-o>", "blur", mode = "t" },
            t_c_q = {
              "<c-q>",
              function()
                vim.cmd("stopinsert")
              end,
              mode = "t",
            },
            n_c_q = { "<c-q>", "hide" }, -- with t_c_q, double `<c-q>` will hide
            hide_ctrl_z = { "<c-z>", "hide", mode = { "n", "t" } }, -- conflicts with fish undo
            n_esc = {
              "<esc>",
              function(self)
                if not U.keymap.clear_ui_esc() then
                  self:execute("blur")
                end
              end,
              desc = "Clear UI or Blur",
            },
          },
        },
      },
    },
  },

  {
    "folke/snacks.nvim",
    opts = function()
      -- work-around for zsh-vi-mode/fish_vi_key_bindings auto insert
      if vim.o.shell:find("zsh") or vim.o.shell:find("fish") then
        vim.api.nvim_create_autocmd("TermEnter", {
          group = vim.api.nvim_create_augroup("shell_vi_mode", {}),
          pattern = "term://*" .. vim.o.shell,
          desc = "Enter insert mode of zsh-vi-mode or fish_vi_key_bindings",
          callback = function(event)
            if vim.bo[event.buf].filetype ~= "snacks_terminal" then
              return
            end
            vim.schedule(function()
              -- powerlevel10k for zsh-vi-mode or starship for fish_vi_key_bindings
              if vim.api.nvim_get_current_line():match("^❮ .*") then
                -- use `a` instead of `i` to restore cursor position
                vim.api.nvim_feedkeys("a", "n", false)
              end
            end)
          end,
        })
      end
    end,
  },

  -- https://github.com/willothy/nvim-config/blob/b5db7b8b7fe6258770c98f12337d6954a56b95e7/lua/configs/terminal/flatten.lua
  -- alternative:
  -- - https://github.com/hat0uma/dotfiles/blob/d01f24164f7dda71c2cab2cccd54cca8ba386e13/.config/nvim/lua/rc/terminal/editor.lua#L7-L9
  -- - https://github.com/brianhuster/unnest.nvim
  -- TODO: `nvim .` with oil not working
  {
    "willothy/flatten.nvim",
    -- if the YAZI_ID environment variable is set, then we are in a yazi
    -- session. To avoid issues with bulk renaming, we disable flatten.nvim
    enabled = vim.env.YAZI_ID == nil,
    lazy = false,
    priority = 1001,
    -- keys = {
    --   {
    --     "<Leader>gc",
    --     function()
    --       local root = LazyVim.root.git() -- Snacks.git.get_root()
    --       -- TODO:
    --       -- - delete terminal buffer with `[Process exited 1]`
    --       -- - notify when something is wrong (e.g., no changes to commit)
    --       local terminal = Snacks.terminal.open(
    --         { "git", "-C", root, "commit", "--verbose" },
    --         { interactive = false, auto_close = true }
    --       )
    --       terminal:hide()
    --     end,
    --     desc = "Commit (Flatten)",
    --   },
    -- },
    opts = function()
      local current_terminal ---@type snacks.win?

      ---@module "flatten",
      ---@type Flatten.Config|{}
      return {
        window = {
          -- require("flatten.core").smart_open()
          -- require("snacks.picker.core.main").new({ float = false, file = false }):get()
          open = "smart",
        },
        nest_if_no_args = true,
        hooks = {
          should_block = function(argv)
            -- use `nvim -b file1` instead of `nvim --cmd 'let g:flatten_wait=1' file1` for shortcuts
            return vim.tbl_contains(argv, "-b")
          end,
          should_nest = function(host)
            if vim.env.NVIM_FLATTEN_NEST then
              return true
            end
            return require("flatten").hooks.should_nest(host)
          end,
          no_files = function(opts)
            if not require("flatten").config.nest_if_no_args then
              return false
            end

            ---copied from: https://github.com/willothy/flatten.nvim/blob/ea99c8c7e9ee4fd66d749a102462d5610126b988/lua/flatten/core.lua#L53-L72
            ---@param argv string[]
            ---@return string[] pre_cmds, string[] post_cmds
            local function parse_argv(argv)
              local pre_cmds, post_cmds = {}, {}
              local is_cmd = false
              for _, arg in ipairs(argv) do
                if is_cmd then
                  is_cmd = false
                  -- execute --cmd <cmd> commands
                  table.insert(pre_cmds, arg)
                elseif arg:sub(1, 1) == "+" then
                  local cmd = string.sub(arg, 2, -1)
                  table.insert(post_cmds, cmd)
                elseif arg == "--cmd" then
                  -- next arg is the actual command
                  is_cmd = true
                end
              end
              return pre_cmds, post_cmds
            end

            -- HACK: fix `nest_if_no_args = true`, see: https://github.com/willothy/flatten.nvim/issues/108
            local pre_cmds, post_cmds = (require("flatten.core").parse_argv or parse_argv)(opts.argv)
            if #pre_cmds > 0 or #post_cmds > 0 then
              return false
            end

            return true
          end,
          pre_open = function()
            if vim.bo.filetype == "snacks_terminal" then
              local win = vim.api.nvim_get_current_win()
              ---@param t snacks.win
              current_terminal = vim.tbl_filter(function(t)
                return t.win == win
              end, Snacks.terminal.list())[1]
            end
          end,
          -- hide the terminal after flattening
          post_open = function(opts)
            if current_terminal then
              current_terminal:hide()
              if not opts.is_blocking then
                current_terminal = nil
              end
            end
          end,
          -- reopen the terminal after blocking ends, like gitcommit
          block_end = function()
            vim.schedule(function()
              if current_terminal then
                current_terminal:show()
                current_terminal = nil
              end
            end)
          end,
        },
      }
    end,
  },
}
