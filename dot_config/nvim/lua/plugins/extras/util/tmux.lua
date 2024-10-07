return {
  -- https://github.com/arturgoms/nvim/blob/045c55460e36e1d4163b426b2ac66bd710721ac5/lua/3thparty/plugins/tmux.lua
  {
    "aserowy/tmux.nvim",
    cond = vim.env.TMUX ~= nil and vim.env.WEZTERM_UNIX_SOCKET == nil, -- tmux but not in wezterm
    -- stylua: ignore
    keys = {
      -- Move to window
      -- https://github.com/aserowy/tmux.nvim/issues/92#issuecomment-1452428973
      { "<C-h>", mode = { "n", "t" }, [[<cmd>lua require("tmux").move_left()<cr>]], desc = "Go to Left Window" },
      { "<C-j>", mode = { "n", "t" }, [[<cmd>lua require("tmux").move_bottom()<cr>]], desc = "Go to Lower Window" },
      { "<C-k>", mode = { "n", "t" }, [[<cmd>lua require("tmux").move_top()<cr>]], desc = "Go to Upper Window" },
      { "<C-l>", mode = { "n", "t" }, [[<cmd>lua require("tmux").move_right()<cr>]], desc = "Go to Right Window" },
      -- Resize window
      -- note: A-hjkl for move lines (by both LazyVim's default keybindings and lazyvim.plugins.extras.editor.mini-move)
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
      -- define keybindings in ../config/keymaps.lua to override LazyVim's default keybindings
      navigation = {
        -- cycles to opposite pane while navigating into the border
        cycle_navigation = false,
        -- enables default keybindings (C-hjkl) for normal mode
        enable_default_keybindings = false,
      },
      resize = {
        -- enables default keybindings (A-hjkl) for normal mode
        enable_default_keybindings = false,
      },
    },
  },

  {
    "mrjones2014/smart-splits.nvim",
    lazy = false,
    cond = vim.env.WEZTERM_UNIX_SOCKET ~= nil,
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
    opts = {
      ignored_filetypes = { "NvimTree", "neo-tree" },
      -- TODO: maybe use `at_edge` function to navigation between tmux and wezterm
      at_edge = "stop",
      disable_multiplexer_nav_when_zoomed = false,
    },
  },

  {
    "willothy/wezterm.nvim",
    lazy = true,
    cond = vim.env.WEZTERM_UNIX_SOCKET ~= nil,
    opts = {
      create_commands = false,
    },
  },

  {
    "folke/zen-mode.nvim",
    optional = true,
    opts = function(_, opts)
      if not vim.env.TMUX and not vim.env.WEZTERM_UNIX_SOCKET then
        return
      end

      -- https://github.com/folke/zen-mode.nvim/issues/111
      vim.api.nvim_create_autocmd("VimLeavePre", {
        desc = "Restore tmux status line and wezterm pane zoom state when close Neovim in Zen Mode",
        callback = function()
          if vim.g.user_zenmode_on then
            require("zen-mode").close()
          end
        end,
      })

      local on_open = opts.on_open or function() end
      local on_close = opts.on_close or function() end

      local on_open_tmux = function() end
      local on_close_tmux = function() end

      if vim.env.TMUX then
        -- https://github.com/folke/zen-mode.nvim/blob/a31cf7113db34646ca320f8c2df22cf1fbfc6f2a/lua/zen-mode/plugins.lua#L96
        local function get_tmux_opt(option)
          local option_raw = vim.fn.system([[tmux show -w ]] .. option)
          if option_raw == "" then
            option_raw = vim.fn.system([[tmux show -g ]] .. option)
          end
          local opt = vim.split(vim.trim(option_raw), " ")[2]
          return opt
        end

        local tmux_status = get_tmux_opt("status")
        local augroup = vim.api.nvim_create_augroup("zenmode_tmux", { clear = true })
        -- https://github.com/TranThangBin/.dotfiles/blob/01a5013b351aaf2b79aa7d771fdc2cec5d861799/nvim/.config/nvim/lua/tranquangthang/lazy/zen-mode.lua#L39
        on_open_tmux = function()
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
          vim.api.nvim_clear_autocmds({ group = augroup })
        end
      end

      local on_open_wezterm = function() end
      local on_close_wezterm = function() end

      if vim.env.WEZTERM_UNIX_SOCKET then
        local wezterm = require("wezterm")

        local function get_pane_zoom_state()
          local panes = wezterm.list_panes()
          if not panes then
            return
          end
          local is_zoomed = false
          for _, p in ipairs(panes) do
            if p.is_zoomed then
              is_zoomed = true
              break
            end
          end
          return is_zoomed
        end

        local is_zoomed
        on_open_wezterm = function()
          is_zoomed = get_pane_zoom_state()
          if not is_zoomed then
            wezterm.zoom_pane(nil, { zoom = true })
          end
        end
        on_close_wezterm = function()
          -- restore zoom state
          if not is_zoomed then
            wezterm.zoom_pane(nil, { unzoom = true })
          end
        end
      end

      opts.on_open = function()
        on_open()
        on_open_tmux()
        on_open_wezterm()
      end
      opts.on_close = function()
        on_close()
        on_close_tmux()
        on_close_wezterm()
      end
    end,
  },
}
