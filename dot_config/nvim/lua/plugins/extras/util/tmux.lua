local is_tmux = vim.g.user_is_tmux
local is_wezterm = vim.g.user_is_wezterm
local is_kitty = vim.g.user_is_kitty

-- https://github.com/folke/zen-mode.nvim/blob/a31cf7113db34646ca320f8c2df22cf1fbfc6f2a/lua/zen-mode/plugins.lua#L96
local function get_tmux_opt(option)
  local option_raw = vim.fn.system([[tmux show -w ]] .. option)
  if option_raw == "" then
    option_raw = vim.fn.system([[tmux show -g ]] .. option)
  end
  local opt = vim.split(vim.trim(option_raw), " ")[2]
  return opt
end

---@param snacks? boolean
---@return {autocmds:function,on_open:function,on_close:function}
local function zen(snacks)
  -- toggle tmux status line
  local on_open_tmux = function() end
  local on_close_tmux = function() end
  if is_tmux then
    local tmux_status
    local tmux_pane
    local augroup = vim.api.nvim_create_augroup("zenmode_tmux", { clear = true })
    -- https://github.com/TranThangBin/.dotfiles/blob/01a5013b351aaf2b79aa7d771fdc2cec5d861799/nvim/.config/nvim/lua/tranquangthang/lazy/zen-mode.lua#L39
    on_open_tmux = function()
      tmux_status = get_tmux_opt("status")
      if snacks then
        tmux_pane = get_tmux_opt("pane-border-status")
        vim.fn.system([[tmux set -w pane-border-status off]])
        vim.fn.system([[tmux set status off]])
        vim.fn.system([[tmux list-panes -F '\#F' | grep -q Z || tmux resize-pane -Z]])
      end
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
      if snacks then
        if type(tmux_pane) == "string" then
          vim.fn.system(string.format([[tmux set -w pane-border-status %s]], tmux_pane))
        else
          vim.fn.system([[tmux set -uw pane-border-status]])
        end
        vim.fn.system(string.format([[tmux set status %s]], tmux_status))
        vim.fn.system([[tmux list-panes -F '\#F' | grep -q Z && tmux resize-pane -Z]])
      end
      vim.api.nvim_clear_autocmds({ group = augroup })
    end
  end

  -- toggle wezterm pane zoom state
  local on_open_wezterm = function() end
  local on_close_wezterm = function() end
  if is_wezterm then
    local wezterm = require("wezterm")
    if wezterm.list_clients() then -- sometimes `wezterm cli` went wrong in tmux, check it
      local smart_splits_wezterm = require("smart-splits.mux.wezterm")

      -- local function pane_is_zoomed(pane_id)
      --   if not pane_id then
      --     return
      --   end
      --
      --   local panes = wezterm.list_panes()
      --   if not panes then
      --     return
      --   end
      --
      --   for _, p in ipairs(panes) do
      --     if p.pane_id == pane_id then
      --       return p.is_zoomed
      --     end
      --   end
      -- end

      local pane_id = smart_splits_wezterm.current_pane_id() -- will pane_id change during nvim session?
      local is_zoomed
      on_open_wezterm = function()
        -- is_zoomed = pane_is_zoomed(pane_id) -- alternative
        is_zoomed = smart_splits_wezterm.current_pane_is_zoomed()
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
  end

  return {
    autocmds = function()
      if not is_tmux and not is_wezterm then
        return
      end

      -- https://github.com/folke/zen-mode.nvim/issues/111
      vim.api.nvim_create_autocmd("VimLeavePre", {
        desc = "Restore tmux status line and wezterm pane zoom state when close Neovim in Zen Mode",
        callback = function()
          if U.toggle.zen:get() then
            U.toggle.zen:set(false)
          end
        end,
      })
    end,
    on_open = function()
      on_open_tmux()
      on_open_wezterm()
    end,
    on_close = function()
      on_close_tmux()
      on_close_wezterm()
    end,
  }
end

return {
  -- https://github.com/arturgoms/nvim/blob/045c55460e36e1d4163b426b2ac66bd710721ac5/lua/3thparty/plugins/tmux.lua
  {
    "aserowy/tmux.nvim",
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
    cond = is_wezterm or is_kitty,
    -- build = "./kitty/install-kittens.bash", -- ~/.config/kitty/neighboring_window.py has been modified to adapt to tmux in kitty
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
              vim.tbl_contains(config.ignored_buftypes, vim.bo.buftype)
              or vim.tbl_contains(config.ignored_filetypes, vim.bo.filetype)
            then
              return -- just stop
            end
            ctx.split()
          elseif at_edge == AtEdgeBehavior.stop then
            return
          end
        end

        if not ((is_wezterm or is_kitty) and ctx.mux and ctx.mux.type == Multiplexer.tmux) then
          -- "wezterm/kitty without tmux" or "tmux not in wezterm/kitty" or "not in any mux", original at_edge behavior
          wrap_or_split_or_stop()
          return
        end

        if is_wezterm then
          -- (nvim in) tmux in wezterm: currently at the edge of tmux, we will check whether it's at the edge of wezterm as well
          local mux_wezterm = require("smart-splits.mux.wezterm")
          local wezterm = require("wezterm")

          -- NOTE: `$WEZTERM_PANE` could be wrong when getting wezterm pane_id in tmux, use `wezterm cli list-clients --format=json` instead
          -- See: https://github.com/wez/wezterm/issues/3413#issuecomment-1491870672
          -- In this case, we need to specify the `--pane-id` for `wezterm cli get-pane-direction`, otherwise it will use `$WEZTERM_PANE`
          -- See: `wezterm cli get-pane-direction --help`
          -- local wezterm_pane_id = wezterm.get_current_pane() -- `$WEZTERM_PANE` could be wrong
          local wezterm_pane_id = mux_wezterm.current_pane_id()
          -- local at_edge_of_wezterm = mux_wezterm.current_pane_at_edge(ctx.direction) -- missing `--pane-id`
          ---@diagnostic disable-next-line: param-type-mismatch
          local at_edge_of_wezterm = wezterm.get_pane_direction(ctx.direction, wezterm_pane_id) == nil
          if at_edge_of_wezterm then
            -- at the edge of both tmux and wezterm, original at_edge behavior
            wrap_or_split_or_stop()
          else
            -- at the edge of tmux, but not at the edge of wezterm, navigate to wezterm
            -- local ok = mux_wezterm.next_pane(ctx.direction) -- missing `--pane-id`
            -- if not ok then
            --   wrap_or_split_or_stop()
            -- end
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
    -- -- NOTE: For tmux in wezterm/kitty, smart-splits.nvim treats tmux as the multiplexer.
    -- -- It will only handle tmux's startup/shutdown events in `setup`, but not wezterm/kitty's, which results in the lack of `SetUserVar=IS_NVIM` for wezterm/kitty.
    -- -- See: https://github.com/mrjones2014/smart-splits.nvim/blob/0523920a07c54eea7610f342ca8c1bddbee4b626/lua/smart-splits/mux/utils.lua#L59
    -- -- The following code fails to set `IS_NVIM` for wezterm/kitty, probably need https://github.com/wez/wezterm/blob/6f375e29a2c4d70b8b51956edd494693196c6692/assets/shell-integration/wezterm.sh#L442.
    -- -- But in `wezterm/keys.lua`/`kitty/kitty.conf`, we pass the C-hjkl keys through to either nvim or tmux, so it's OK to not set `IS_NVIM` and let wezterm/kitty treat it as tmux.
    -- config = function(_, opts)
    --   require("smart-splits").setup(opts)
    --
    --   local mux = require("smart-splits.mux").get()
    --   local Multiplexer = require("smart-splits.types").Multiplexer
    --
    --   -- tmux in wezterm/kitty
    --   if (is_wezterm or is_kitty) and mux and mux.type == Multiplexer.tmux then
    --     local mux_wezterm_or_kitty = is_wezterm and require("smart-splits.mux.wezterm")
    --       or require("smart-splits.mux.kitty")
    --     -- alternative to `on_init()`:
    --     -- - require("wezterm").set_user_var("IS_NVIM", true)
    --     -- - https://github.com/folke/dot/blob/39602b7edc7222213bce762080d8f46352167434/nvim/lua/util/init.lua#L152
    --     mux_wezterm_or_kitty.on_init()
    --     vim.api.nvim_create_autocmd("VimResume", {
    --       callback = function()
    --         mux_wezterm_or_kitty.on_init()
    --       end,
    --     })
    --     vim.api.nvim_create_autocmd({ "VimSuspend", "VimLeavePre" }, {
    --       callback = function()
    --         mux_wezterm_or_kitty.on_exit()
    --       end,
    --     })
    --   end
    -- end,
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

  -- -- Manage wezterm types for ~/.config/wezterm/*.lua with lazy. Plugin will never be loaded
  -- { "justinsgithub/wezterm-types", cond = is_wezterm, lazy = true },
  -- {
  --   "folke/lazydev.nvim",
  --   opts = function(_, opts)
  --     if not is_wezterm then
  --       return
  --     end
  --
  --     -- opts.debug = true
  --     opts.library = opts.library or {}
  --     if LazyVim.has("wezterm.nvim") then
  --       table.insert(opts.library, { path = "wezterm-types", words = { "%-%-%[%[@as Wezterm%]%]" } })
  --     else
  --       table.insert(opts.library, { path = "wezterm-types", mods = { "wezterm" } }) -- conflicts with willothy/wezterm.nvim
  --     end
  --   end,
  -- },

  {
    "folke/zen-mode.nvim",
    optional = true,
    opts = function(_, opts)
      local z = zen()
      z.autocmds()
      local on_open = opts.on_open or function() end
      local on_close = opts.on_close or function() end
      opts.on_open = function()
        on_open()
        z.on_open()
      end
      opts.on_close = function()
        on_close()
        z.on_close()
      end
    end,
  },

  {
    "folke/snacks.nvim",
    optional = true,
    opts = function(_, opts)
      local z = zen(true)
      z.autocmds()
      opts.zen = opts.zen or {}
      local on_open = opts.zen.on_open or function() end
      local on_close = opts.zen.on_close or function() end
      opts.zen.on_open = function()
        on_open()
        z.on_open()
      end
      opts.zen.on_close = function()
        on_close()
        z.on_close()
      end
    end,
  },
}
