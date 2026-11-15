local is_tmux = vim.g.user_is_tmux
local is_wezterm = vim.g.user_is_wezterm
local is_kitty = vim.g.user_is_kitty
-- TODO: tmux in ghostty
local is_ghostty = vim.g.user_is_ghostty

---@type LazySpec
return {
  {
    "gpakosz/.tmux",
    name = "oh-my-tmux",
    lazy = true,
    config = function() end,
    build = function(plugin)
      local tmux_conf = vim.fn.expand("~/.config/tmux/tmux.conf") --[[@as string]]
      vim.fn.mkdir(vim.fn.fnamemodify(tmux_conf, ":h"), "p")
      local res = vim.system({ "ln", "-sfn", plugin.dir .. "/.tmux.conf", tmux_conf }):wait()
      assert(res.code == 0, "Failed to link oh-my-tmux: " .. (res.stderr or ""))
    end,
    specs = {
      {
        "LazyVim/LazyVim",
        opts = function()
          if not U.path.CHEZMOI then
            return
          end

          local tmux_conf_local = U.path.CHEZMOI .. "/dot_config/tmux/tmux.conf.local"
          vim.api.nvim_create_autocmd("BufRead", {
            group = vim.api.nvim_create_augroup("oh_my_tmux_keymaps", {}),
            pattern = tmux_conf_local,
            callback = function(ev)
              vim.keymap.set("n", "<localleader>d", function()
                local omt_dir = require("lazy.core.config").spec.plugins["oh-my-tmux"].dir
                local cmd = { "delta", "--paging", "never", omt_dir .. "/.tmux.conf.local", tmux_conf_local }
                Snacks.terminal(cmd, {
                  interactive = false,
                  win = {
                    height = U.snacks.win.fullscreen_height,
                    width = 0,
                    title = "oh-my-tmux .tmux.conf.local",
                    zindex = (vim.api.nvim_win_get_config(0).zindex or 50) + 1,
                    b = { user_lualine_filename = "diff" },
                  },
                })
              end, { buffer = ev.buf, desc = "Diff with upstream oh-my-tmux" })
            end,
          })
        end,
      },
    },
  },

  -- https://github.com/arturgoms/nvim/blob/045c55460e36e1d4163b426b2ac66bd710721ac5/lua/3thparty/plugins/tmux.lua
  {
    "aserowy/tmux.nvim",
    pager = true,
    cond = is_tmux and not (is_wezterm or is_kitty), -- tmux but not in wezterm/kitty
    -- stylua: ignore
    keys = {
      -- Move to window
      -- https://github.com/aserowy/tmux.nvim/issues/92#issuecomment-1452428973
      { "<C-h>", mode = { "n", "t" }, [[<cmd>lua require("tmux").move_left()<cr>]], desc = "Go to Left Window" },
      { "<C-j>", mode = { "n", "t" }, [[<cmd>lua require("tmux").move_bottom()<cr>]], desc = "Go to Lower Window" },
      { "<C-k>", mode = { "n", "t" }, [[<cmd>lua require("tmux").move_top()<cr>]], desc = "Go to Upper Window" },
      { "<C-l>", mode = { "n", "t" }, [[<cmd>lua require("tmux").move_right()<cr>]], desc = "Go to Right Window" },
      -- Resize window
      -- note: A-hjkl is used for move lines (by both LazyVim's default keybindings and extras.editor.mini-move)
      -- need to disable macOS keybord shortcuts of mission control first
      -- TODO: resize LazyVim's terminal
      { "<C-Left>", mode = { "n", "t" }, [[<cmd>lua require("tmux").resize_left()<cr>]], desc = "Resize Window Left" },
      { "<C-Down>", mode = { "n", "t" }, [[<cmd>lua require("tmux").resize_bottom()<cr>]], desc = "Resize Window Bottom" },
      { "<C-Up>", mode = { "n", "t" }, [[<cmd>lua require("tmux").resize_top()<cr>]], desc = "Resize Window Top" },
      { "<C-Right>", mode = { "n", "t" }, [[<cmd>lua require("tmux").resize_right()<cr>]], desc = "Resize Window Right" },
    },
    opts = {
      -- To work with yanky.nvim, see:
      -- https://github.com/moetayuko/nvimrc/blob/ae242cc18559cd386c36feb9f999b1a9596c7d09/lua/plugins/tmux.lua
      -- https://github.com/aserowy/tmux.nvim/pull/123
      copy_sync = {
        -- sync all registers
        enable = false,
      },
      navigation = {
        cycle_navigation = false,
        enable_default_keybindings = false,
      },
      resize = {
        enable_default_keybindings = false,
      },
      swap = {
        enable_default_keybindings = false,
      },
    },
  },

  {
    "mrjones2014/smart-splits.nvim",
    pager = true,
    cond = is_wezterm or is_kitty or is_ghostty,
    -- build = "./kitty/install-kittens.bash", -- ~/.config/kitty/neighboring_window.py has been modified to adapt to tmux in kitty
    build = function(plugin)
      if vim.fn.executable("herdr") == 1 then
        -- https://github.com/mrjones2014/smart-splits.nvim/blob/9836ec9bef9801937e5e7100af801f37b77eacab/README.md?plain=1#L618-L620
        local res = vim.system({ "herdr", "plugin", "link", plugin.dir }, { stdout = false }):wait()
        if res.code ~= 0 then
          require("lazyvim.util").warn(
            ("Failed to run `herdr plugin link %s`:\n%s"):format(plugin.dir, res.stderr),
            { title = "smart-splits.nvim" }
          )
        end
      end
    end,
    lazy = false, -- required
    -- stylua: ignore
    keys = {
      { "<C-h>", mode = { "n", "t" }, function() require("smart-splits").move_cursor_left() end, desc = "Go to Left Window" },
      { "<C-j>", mode = { "n", "t" }, function() require("smart-splits").move_cursor_down() end, desc = "Go to Lower Window" },
      { "<C-k>", mode = { "n", "t" }, function() require("smart-splits").move_cursor_up() end, desc = "Go to Upper Window" },
      { "<C-l>", mode = { "n", "t" }, function() require("smart-splits").move_cursor_right() end, desc = "Go to Right Window" },
      { "<C-Left>", function() require("smart-splits").resize_left() end, desc = "Resize Window Left" },
      { "<C-Down>", function() require("smart-splits").resize_down() end, desc = "Resize Window Bottom" },
      { "<C-Up>", function() require("smart-splits").resize_up() end, desc = "Resize Window Top" },
      { "<C-Right>", function() require("smart-splits").resize_right() end, desc = "Resize Window Right" },
      { "<leader><C-h>", function() require("smart-splits").swap_buf_left() end, desc = "Swap Buffer Left" },
      { "<leader><C-j>", function() require("smart-splits").swap_buf_down() end, desc = "Swap Buffer Down" },
      { "<leader><C-k>", function() require("smart-splits").swap_buf_up() end, desc = "Swap Buffer Up" },
      { "<leader><C-l>", function() require("smart-splits").swap_buf_right() end, desc = "Swap Buffer Right" },
    },
    ---@type SmartSplitsConfig|{}
    opts = {
      ignored_filetypes = { "NvimTree", "neo-tree" },
      --- for tmux in wezterm: navigate from tmux panes to wezterm panes
      --- https://github.com/mrjones2014/smart-splits.nvim/blob/0523920a07c54eea7610f342ca8c1bddbee4b626/lua/smart-splits/api.lua#L382
      ---@param ctx SmartSplitsContext
      at_edge = function(ctx)
        local config = require("smart-splits.lazy").require_on_index("smart-splits.config") --[[@as SmartSplitsConfig]]
        local types = require("smart-splits.types")
        local AtEdgeBehavior = types.AtEdgeBehavior
        local Multiplexer = types.Multiplexer

        local at_edge = AtEdgeBehavior.stop -- config here: wrap, split, stop

        local function wrap_or_split_or_stop()
          if at_edge == AtEdgeBehavior.wrap then
            ---@diagnostic disable-next-line: undefined-field
            ctx.wrap()
          elseif at_edge == AtEdgeBehavior.split then
            if
              vim.list_contains(config.ignored_buftypes, vim.bo.buftype)
              or vim.list_contains(config.ignored_filetypes, vim.bo.filetype)
            then
              return -- just stop
            end
            ctx.split()
          elseif at_edge == AtEdgeBehavior.stop then
            return
          end
        end

        if
          not (
            (is_wezterm or is_kitty)
            and ctx.mux
            and vim.list_contains({ Multiplexer.tmux, Multiplexer.herdr }, ctx.mux.type)
          )
        then
          -- "wezterm/kitty without tmux/herdr" or "tmux/herdr not in wezterm/kitty" or "not in any mux", original at_edge behavior
          wrap_or_split_or_stop()
          return
        end

        if is_wezterm then
          -- (nvim in) tmux in wezterm: currently at the edge of tmux, we will check whether it's at the edge of wezterm as well
          local wezterm = require("wezterm")

          -- `$WEZTERM_PANE` could be wrong in tmux. So we need to specify the `--pane-id` for `wezterm cli get-pane-direction`,
          -- otherwise it will use `$WEZTERM_PANE`, see: `wezterm cli get-pane-direction --help`.
          local wezterm_pane_id = U.mux.wezterm.current_pane_id()
          if not wezterm_pane_id then
            return
          end
          ---@diagnostic disable-next-line: param-type-mismatch
          local at_edge_of_wezterm = wezterm.get_pane_direction(ctx.direction, wezterm_pane_id) == nil
          if at_edge_of_wezterm then
            -- at the edge of both tmux and wezterm, original at_edge behavior
            wrap_or_split_or_stop()
          else
            -- at the edge of tmux, but not at the edge of wezterm, navigate to wezterm
            ---@diagnostic disable-next-line: param-type-mismatch
            wezterm.switch_pane.direction(ctx.direction, wezterm_pane_id)
          end
        elseif is_kitty then
          local mux_kitty = require("smart-splits.mux.kitty")
          local at_edge_of_kitty = mux_kitty.current_pane_at_edge(ctx.direction)
          if at_edge_of_kitty then
            wrap_or_split_or_stop()
          else
            mux_kitty.next_pane(ctx.direction)
          end
        end
      end,
      -- float_win_behavior = "mux",
      disable_multiplexer_nav_when_zoomed = false,
    },
    -- NOTE: For tmux in wezterm/kitty, smart-splits.nvim treats tmux as the multiplexer.
    -- It will only handle tmux's startup/shutdown events in `setup`, but not wezterm/kitty's, which results in the lack of `SetUserVar=IS_NVIM` for wezterm/kitty.
    -- See: https://github.com/mrjones2014/smart-splits.nvim/blob/0523920a07c54eea7610f342ca8c1bddbee4b626/lua/smart-splits/mux/utils.lua#L59
    -- But in `wezterm/keys.lua`/`kitty/kitty.conf`, we pass the C-hjkl keys through to either nvim or tmux, so it's OK to not set `IS_NVIM` and let wezterm/kitty treat it as tmux.
  },

  -- library
  {
    "willothy/wezterm.nvim",
    cond = is_wezterm,
    lazy = true,
    opts = {
      create_commands = false,
    },
  },

  -- Manage wezterm types for ~/.config/wezterm/*.lua with lazy. Plugin will never be loaded
  { "DrKJeff16/wezterm-types", cond = is_wezterm, lazy = true, config = function() end },
  {
    "folke/lazydev.nvim",
    opts = function(_, opts)
      if not is_wezterm then
        return
      end

      -- opts.debug = true
      opts.library = opts.library or {}
      if LazyVim.has("wezterm.nvim") then
        table.insert(opts.library, { path = "wezterm-types", words = { "%-%-%[%[@as Wezterm%]%]" } })
      else
        table.insert(opts.library, { path = "wezterm-types", mods = { "wezterm" } }) -- conflicts with willothy/wezterm.nvim
      end
      table.insert(opts.library, { path = "wez-tmux", mods = { "wez-tmux" } })
    end,
  },

  {
    "folke/snacks.nvim",
    optional = true,
    opts = function(_, opts)
      -- toggle tmux status line
      local on_open_tmux = function() end
      local on_close_tmux = function() end
      if is_tmux then
        local tmux_status
        local tmux_pane
        local augroup = vim.api.nvim_create_augroup("snacks_zen_tmux", { clear = true })
        -- https://github.com/TranThangBin/.dotfiles/blob/01a5013b351aaf2b79aa7d771fdc2cec5d861799/nvim/.config/nvim/lua/tranquangthang/lazy/zen-mode.lua#L39
        on_open_tmux = function()
          tmux_status = U.mux.tmux.get_opt("status")
          tmux_pane = U.mux.tmux.get_opt("pane-border-status")
          vim.fn.system([[tmux set -w pane-border-status off]])
          vim.fn.system([[tmux set status off]])
          vim.fn.system([[tmux list-panes -F '\#F' | grep -q Z || tmux resize-pane -Z]])
          -- restore tmux status line when switching to another tmux window or ctrl-z
          vim.api.nvim_create_autocmd({ "FocusLost", "VimSuspend" }, {
            group = augroup,
            desc = "Restore tmux status line on Neovim Focus Lost",
            callback = function()
              vim.fn.system(string.format([[tmux set status %s]], tmux_status))
            end,
          })
          vim.api.nvim_create_autocmd({ "FocusGained", "VimResume" }, {
            group = augroup,
            desc = "Hide tmux status line on Neovim Focus Gained",
            callback = function()
              vim.fn.system([[tmux set status off]])
            end,
          })
        end
        on_close_tmux = function()
          if type(tmux_pane) == "string" then
            vim.fn.system(string.format([[tmux set -w pane-border-status %s]], tmux_pane))
          else
            vim.fn.system([[tmux set -uw pane-border-status]])
          end
          vim.fn.system(string.format([[tmux set status %s]], tmux_status))
          vim.fn.system([[tmux list-panes -F '\#F' | grep -q Z && tmux resize-pane -Z]])
          vim.api.nvim_clear_autocmds({ group = augroup })
        end
      end

      -- toggle wezterm pane zoom state
      local on_open_wezterm = function() end
      local on_close_wezterm = function() end
      if is_wezterm and LazyVim.has("wezterm.nvim") then
        local wezterm = require("wezterm")
        local pane_id, is_zoomed
        on_open_wezterm = function()
          pane_id = U.mux.wezterm.current_pane_id()
          is_zoomed = U.mux.wezterm.pane_is_zoomed(pane_id)
          if is_zoomed == false then
            wezterm.zoom_pane(pane_id, { zoom = true })
          end
        end
        on_close_wezterm = function()
          -- restore zoom state
          if is_zoomed == false then
            wezterm.zoom_pane(pane_id, { unzoom = true })
          end
        end
      end

      -- toggle kitty window layout (zoom)
      local on_open_kitty = function() end
      local on_close_kitty = function() end
      if is_kitty and LazyVim.has("smart-splits.nvim") then
        local smart_splits_kitty = require("smart-splits.mux.kitty")
        local is_zoomed
        on_open_kitty = function()
          is_zoomed = smart_splits_kitty.current_pane_is_zoomed()
          if is_zoomed == false then
            vim.system({ "kitten", "@", "goto-layout", "stack" })
          end
        end
        on_close_kitty = function()
          -- restore window layout
          if is_zoomed == false then
            vim.system({ "kitten", "@", "last-used-layout" })
          end
        end
      end

      if is_tmux or is_wezterm or is_kitty then
        -- https://github.com/folke/zen-mode.nvim/issues/111
        vim.api.nvim_create_autocmd("VimLeavePre", {
          desc = "Restore tmux status line and wezterm pane zoom state when close Neovim in Zen Mode",
          callback = function()
            if assert(Snacks.toggle.get("zen")):get() then
              -- `U.toggle.zen:set(false)` not working for snacks zen
              on_close_tmux()
              on_close_wezterm()
              on_close_kitty()
            end
          end,
        })
      end

      opts.zen = opts.zen or {}
      local orig_on_open = opts.zen.on_open or function() end
      local orig_on_close = opts.zen.on_close or function() end
      opts.zen.on_open = function()
        orig_on_open()
        on_open_tmux()
        on_open_wezterm()
        on_open_kitty()
      end
      opts.zen.on_close = function()
        orig_on_close()
        on_close_tmux()
        on_close_wezterm()
        on_close_kitty()
      end
    end,
  },
}
