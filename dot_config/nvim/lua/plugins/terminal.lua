---@module "lazy"
---@type LazySpec
return {
  {
    "folke/snacks.nvim",
    keys = {
      -- stylua: ignore start
      { "<leader>fT", function() U.terminal() end, desc = "Terminal (cwd)" },
      -- { "<leader>ft", function() U.terminal(nil, { cwd = LazyVim.root() }) end, desc = "Terminal (Root Dir)" },
      -- stylua: ignore end
      {
        "<c-space>",
        function()
          U.terminal(nil, {
            win = { position = "float" },
            cwd = LazyVim.root(),
          })
        end,
        desc = "Terminal (Root Dir)",
      },
      { "<c-space>", "<cmd>close<cr>", desc = "Hide Terminal", mode = "t" },
      {
        "<c-cr>",
        function()
          local filepath = vim.fn.expand("%:p:h")
          U.terminal(nil, { cwd = vim.fn.isdirectory(filepath) == 1 and filepath or LazyVim.root() })
        end,
        desc = "Terminal (Buffer Dir)",
      },
      { "<c-cr>", "<cmd>close<cr>", desc = "Hide Terminal", mode = "t" },
    },
    ---@module "snacks"
    ---@type snacks.Config
    opts = {
      -- terminal = {
      --   win = {
      --     position = "float", -- alternative: style = "float"
      --   },
      -- },
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
                vim.api.nvim_feedkeys(vim.keycode("a"), "n", false)
              end
            end)
          end,
        })
      end
    end,
  },

  -- https://github.com/willothy/nvim-config/blob/b5db7b8b7fe6258770c98f12337d6954a56b95e7/lua/configs/terminal/flatten.lua
  -- TODO: nested `nvim .` with oil not working
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
