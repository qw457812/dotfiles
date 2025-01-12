-- https://wezfurlong.org/wezterm/config/keys.html
-- https://wezfurlong.org/wezterm/config/lua/keyassignment/index.html
--
-- https://github.com/zidhuss/dotfiles/blob/16ea5fc60f20e7ec132cca59bb694a5d54696bb6/wezterm/.config/wezterm/plugins/wez-tmux/init.lua

local wezterm = require("wezterm") --[[@as Wezterm]]
local helpers = require("helpers")
local act = wezterm.action

local wez_tmux = wezterm.plugin.require("https://github.com/sei40kr/wez-tmux")

local M = {}

M.super = "SUPER"
M.leader = "LEADER"

M.action = {
  smart_split = wezterm.action_callback(function(win, pane)
    local dim = pane:get_dimensions()
    if dim.pixel_height > dim.pixel_width then
      win:perform_action(act.SplitVertical({ domain = "CurrentPaneDomain" }), pane)
    else
      win:perform_action(act.SplitHorizontal({ domain = "CurrentPaneDomain" }), pane)
    end
  end),

  next_pane_or_tab_or_window = wezterm.action_callback(function(win, pane)
    local pane_count = #pane:tab():panes()
    local tab_count = #win:mux_window():tabs()
    if pane_count > 1 then
      win:perform_action(act.ActivatePaneDirection("Next"), pane)
    elseif tab_count > 1 then
      win:perform_action(act.ActivateTabRelative(1), pane)
    else
      win:perform_action(act.ActivateWindowRelative(1), pane)
    end
  end),

  open_url = wezterm.action.QuickSelectArgs({
    label = "open url",
    patterns = {
      "\\((https?://\\S+)\\)",
      "\\[(https?://\\S+)\\]",
      "\\{(https?://\\S+)\\}",
      "<(https?://\\S+)>",
      "\\bhttps?://\\S+[)/a-zA-Z0-9-]+",
    },
    action = wezterm.action_callback(function(window, pane)
      local url = window:get_selection_text_for_pane(pane)
      wezterm.log_info("opening: " .. url)
      wezterm.open_with(url)
    end),
  }),

  clear_selection_and_clear_pattern_or_close = wezterm.action_callback(function(window, pane)
    local actions = {}

    local has_selection = window:get_selection_text_for_pane(pane) ~= ""
    local has_pattern = wezterm.GLOBAL.tmux_search_directions[tostring(pane)]

    -- clear selection and pattern at one time, save one `esc` press
    if has_selection or has_pattern then
      if has_selection then
        table.insert(actions, act.ClearSelection)
        table.insert(actions, act.CopyMode("ClearSelectionMode"))
      end
      if has_pattern then
        table.insert(actions, wez_tmux.action.ClearPattern)
      end
    else
      table.insert(actions, act.CopyMode("Close"))
      table.insert(actions, act.ScrollToBottom)
    end

    window:perform_action(act.Multiple(actions), pane)
  end),

  clear_selection_or_clear_pattern_or_close = wezterm.action_callback(function(window, pane)
    local action

    if window:get_selection_text_for_pane(pane) ~= "" then
      action = act.Multiple({
        act.ClearSelection,
        act.CopyMode("ClearSelectionMode"),
      })
    elseif wezterm.GLOBAL.tmux_search_directions[tostring(pane)] then
      action = wez_tmux.action.ClearPattern
    else
      action = act.Multiple({
        act.CopyMode("Close"),
        act.ScrollToBottom,
      })
    end

    window:perform_action(action, pane)
  end),

  close_copy_mode = wezterm.action_callback(function(window, pane)
    wezterm.GLOBAL.tmux_search_directions[tostring(pane)] = nil
    window:perform_action(
      act.Multiple({
        act.ClearSelection,
        act.CopyMode("ClearSelectionMode"),
        act.CopyMode("ClearPattern"),
        act.CopyMode("AcceptPattern"),
        act.CopyMode("Close"),
        act.ScrollToBottom,
      }),
      pane
    )
  end),
}

-- https://wezfurlong.org/wezterm/config/lua/pane/get_foreground_process_name.html
local function get_foreground_process_basename(pane)
  local name = pane:get_foreground_process_name()
  return name and string.gsub(name, "(.*[/\\])(.*)", "%2") or nil
end

-- https://github.com/mrjones2014/smart-splits.nvim#wezterm
-- https://github.com/mrjones2014/smart-splits.nvim/blob/master/plugin/init.lua
-- Do *NOT* lazy-loading smart-splits.nvim
local function is_nvim(pane)
  -- this is set by the Neovim plugin on launch, and unset on ExitPre in Neovim
  return pane:get_user_vars().IS_NVIM == "true" -- or pane:get_foreground_process_name():find("n?vim")
end

local function is_tmux(pane)
  -- https://wezfurlong.org/wezterm/shell-integration.html#user-vars
  -- require `source "/Applications/WezTerm.app/Contents/Resources/wezterm.sh"` in ~/.zshrc
  return pane:get_user_vars().WEZTERM_IN_TMUX == "1"
end

local function is_fzf(pane)
  local process_basename = get_foreground_process_basename(pane)
  -- `--height 100%` is required for is_alt_screen_active, see https://github.com/wez/wezterm/discussions/4101
  return process_basename == "fzf"
    or ((process_basename == "zsh" or process_basename == "fish") and pane:is_alt_screen_active())
end

local function is_lazygit(pane)
  -- should be nvim instead of lazygit after using `e` in lazygit
  return get_foreground_process_basename(pane) == "lazygit" and not is_nvim(pane)
end

---@param resize_or_move "resize"|"move"
---@param mods string
---@param key string
---@param direction "Left"|"Down"|"Up"|"Right"
---@return table
local function split_nav(resize_or_move, mods, key, direction)
  local resize_amount = 3
  return {
    key = key,
    mods = mods,
    action = wezterm.action_callback(function(win, pane)
      if
        is_nvim(pane)
        or is_tmux(pane)
        or ((key == "j" or key == "k") and is_fzf(pane))
        -- or (key == "h" and is_lazygit(pane)) -- make <c-h> close the lazygit
      then
        -- pass the keys through to nvim/tmux/fzf
        win:perform_action({ SendKey = { key = key, mods = mods } }, pane)
      else
        if resize_or_move == "resize" then
          win:perform_action({ AdjustPaneSize = { direction, resize_amount } }, pane)
        else
          -- local panes = pane:tab():panes_with_info()
          -- local is_zoomed = false
          -- for _, p in ipairs(panes) do
          --   if p.is_zoomed then
          --     is_zoomed = true
          --     break
          --   end
          -- end
          -- -- wezterm.log_info("is_zoomed: " .. tostring(is_zoomed))
          -- -- local dir = direction
          -- -- if is_zoomed then
          -- --   dir = (dir == "Up" or dir == "Left") and "Prev" or "Next"
          -- -- end
          -- -- wezterm.log_info("dir: " .. dir)
          -- -- win:perform_action({ ActivatePaneDirection = dir }, pane)
          win:perform_action({ ActivatePaneDirection = direction }, pane)
          -- if is_zoomed then
          --   win:perform_action({ SetPaneZoomState = is_zoomed }, pane)
          -- end
        end
      end
    end),
  }
end

function M.apply_to_config(config)
  -- macOS right option key as alt modifier
  config.send_composed_key_when_right_alt_is_pressed = false

  -- -- tmux like
  -- config.leader = { mods = "CTRL", key = "b", timeout_milliseconds = 1000 }

  -- wezterm show-keys
  config.keys = {
    -- -- Send "CTRL-B" to the terminal when pressing CTRL-B, CTRL-B
    -- { mods = "LEADER|CTRL", key = "b", action = act.SendKey({ key = "b", mods = "CTRL" }) },
    -- { mods = M.leader, key = "s", action = wez_tmux.action.WorkspaceSelect },
    -- { mods = M.leader, key = "-", action = act.SplitVertical({ domain = "CurrentPaneDomain" }) },
    -- { mods = "LEADER|SHIFT", key = "_", action = act.SplitHorizontal({ domain = "CurrentPaneDomain" }) },
    -- { mods = M.leader, key = "z", action = act.TogglePaneZoomState },
    -- { mods = M.leader, key = "x", action = act.CloseCurrentPane({ confirm = false }) },

    -- To distinguish <C-I> and <Tab> in neovim (note that mapping <M-i> to <C-i> in neovim is required)
    {
      mods = "CTRL",
      key = "i",
      action = wezterm.action_callback(function(win, pane)
        win:perform_action({ SendKey = { mods = is_nvim(pane) and "ALT" or "CTRL", key = "i" } }, pane)
      end),
    },

    -- make <bs> close the lazygit
    -- mapped <c-h> to quit in lazygit/config.yml via `quitWithoutChangingDirectory: <backspace>`
    -- when typing a commit message in lazygit, <c-h> and <bs> do the same thing
    {
      key = "Backspace",
      action = wezterm.action_callback(function(win, pane)
        local send_key = is_lazygit(pane) and { mods = "CTRL", key = "h" } or { key = "Backspace" }
        win:perform_action({ SendKey = send_key }, pane)
      end),
    },

    { mods = "CTRL", key = "-", action = act.DisableDefaultAssignment }, -- disable this (DecreaseFontSize) for terminal in nvim
    -- resize panes
    split_nav("resize", "CTRL", "LeftArrow", "Left"),
    split_nav("resize", "CTRL", "RightArrow", "Right"),
    split_nav("resize", "CTRL", "UpArrow", "Up"),
    split_nav("resize", "CTRL", "DownArrow", "Down"),
    -- move between split panes
    split_nav("move", "CTRL", "h", "Left"),
    split_nav("move", "CTRL", "j", "Down"),
    split_nav("move", "CTRL", "k", "Up"),
    split_nav("move", "CTRL", "l", "Right"),
    -- -- cycles panes, then tabs, then windows
    -- { mods = M.super, key = "n", action = M.action.next_pane_or_tab_or_window },
    { mods = M.super, key = "w", action = act.CloseCurrentPane({ confirm = false }) },
    -- Splits
    { mods = M.super, key = "Enter", action = M.action.smart_split },
    { mods = M.super, key = "m", action = act.TogglePaneZoomState },
    { mods = M.super, key = "r", action = act.RotatePanes("Clockwise") },
    -- Tabs
    { mods = M.super, key = "j", action = act({ ActivateTabRelative = 1 }) },
    { mods = M.super, key = "k", action = act({ ActivateTabRelative = -1 }) },
    -- -- Scrollback
    -- { mods = M.super, key = "u", action = act.ScrollByPage(-0.5) },
    -- { mods = M.super, key = "d", action = act.ScrollByPage(0.5) },
    -- Others
    {
      mods = M.super,
      key = "Space",
      -- action = act.ActivateCopyMode,
      action = act.Multiple({
        act.Search({ CaseInSensitiveString = "" }), -- just to ignore case in copy mode
        act.ActivateCopyMode,
      }),
    },
    { mods = M.super, key = ":", action = act.ActivateCommandPalette },
    { mods = M.super, key = "y", action = act.QuickSelect },
    { mods = M.super, key = "d", action = act.ShowDebugOverlay },
    { mods = M.super, key = "u", action = M.action.open_url },
    { -- copy [o]ption (e.g. from a man page)
      mods = M.super,
      key = "o",
      action = act.QuickSelectArgs({
        patterns = { "--[\\w=-]+", "(?<= )-\\w" }, -- long option, short option
        label = "Copy shell option",
      }),
    },
    {
      mods = M.super,
      key = "f",
      -- action = act.Search({ CaseInSensitiveString = "" }),
      action = act.Multiple({
        act.Search({ CaseInSensitiveString = "" }), -- just to ignore case in copy mode
        act.ActivateCopyMode,
        wez_tmux.action.SearchForward,
      }),
    },
    { -- open current location in Finder
      mods = M.super,
      key = "l",
      action = wezterm.action_callback(function(_, pane)
        local cwd = pane:get_current_working_dir().file_path
        wezterm.open_with(cwd, "Finder")
      end),
    },
    -- {
    --   mods = M.super,
    --   key = ",",
    --   action = wezterm.action_callback(function()
    --     wezterm.open_with(wezterm.config_file)
    --   end),
    -- },
  }

  config.key_tables = {}

  -- https://wezfurlong.org/wezterm/config/lua/wezterm.gui/default_key_tables.html
  if wezterm.gui then
    -- Copy Mode
    -- TODO: https://wezfurlong.org/wezterm/copymode.html#configurable-key-assignments
    config.key_tables.copy_mode = helpers.list_extend(wezterm.gui.default_key_tables().copy_mode, {
      { mods = "NONE", key = "H", action = act.CopyMode("MoveToStartOfLineContent") },
      { mods = "NONE", key = "L", action = act.CopyMode("MoveToEndOfLineContent") },
      { mods = "NONE", key = "u", action = act.CopyMode({ MoveByPage = -0.5 }) },
      { mods = "NONE", key = "d", action = act.CopyMode({ MoveByPage = 0.5 }) },
      { mods = "CTRL", key = "u", action = act.CopyMode({ MoveByPage = -0.5 }) },
      { mods = "CTRL", key = "d", action = act.CopyMode({ MoveByPage = 0.5 }) },
      -- { mods = "NONE", key = "Escape", action = M.action.clear_selection_and_clear_pattern_or_close },
      -- { mods = "NONE", key = "Escape", action = wez_tmux.action.ClearSelectionOrClearPatternOrClose },
      { mods = "NONE", key = "Escape", action = M.action.clear_selection_or_clear_pattern_or_close },
      -- -- leave copy mode on `y`
      -- {
      --   mods = "NONE",
      --   key = "y",
      --   action = wezterm.action_callback(function(window, pane)
      --     wezterm.GLOBAL.tmux_search_directions[tostring(pane)] = nil
      --     window:perform_action(
      --       act.Multiple({
      --         act.CopyTo("Clipboard"),
      --         act.ClearSelection,
      --         act.CopyMode("ClearSelectionMode"),
      --         act.CopyMode("ClearPattern"),
      --         act.CopyMode("AcceptPattern"),
      --         act.CopyMode("Close"),
      --         act.ScrollToBottom,
      --       }),
      --       pane
      --     )
      --   end),
      -- },
      -- `y` does not leave copy mode
      {
        mods = "NONE",
        key = "y",
        action = act.Multiple({
          act.CopyTo("Clipboard"),
          act.ClearSelection,
          act.CopyMode("ClearSelectionMode"),
        }),
      },
      -- if `y` does not leave copy mode, then `p` can be used
      {
        mods = "NONE",
        key = "p",
        action = wezterm.action_callback(function(window, pane)
          -- `wez_tmux.action.ClearPattern` | https://github.com/sei40kr/wez-tmux/blob/bec87155863baf161e2358862d001f237f7ea968/plugin/init.lua#L15
          wezterm.GLOBAL.tmux_search_directions[tostring(pane)] = nil
          window:perform_action(
            act.Multiple({
              act.ClearSelection,
              act.CopyMode("ClearSelectionMode"),
              act.CopyMode("ClearPattern"),
              act.CopyMode("AcceptPattern"),
              act.CopyMode("Close"),
              act.PasteFrom("Clipboard"),
            }),
            pane
          )
        end),
      },
      -- leave copy mode on `i` (insert)
      { mods = "NONE", key = "i", action = M.action.close_copy_mode },
      { mods = "NONE", key = "Backspace", action = M.action.close_copy_mode },
      { mods = "NONE", key = "/", action = wez_tmux.action.SearchForward },
      { mods = "NONE", key = "?", action = wez_tmux.action.SearchBackward },
      { mods = "NONE", key = "n", action = wez_tmux.action.NextMatch },
      { mods = "NONE", key = "N", action = wez_tmux.action.PriorMatch },
    })

    -- Search Mode
    config.key_tables.search_mode = helpers.list_extend(wezterm.gui.default_key_tables().search_mode, {
      {
        mods = "NONE",
        key = "Enter",
        action = act.Multiple({
          act.CopyMode("AcceptPattern"),
          act.ClearSelection,
          act.CopyMode("ClearSelectionMode"),
        }),
      },
      {
        mods = "NONE",
        key = "Escape",
        -- action = wez_tmux.action.ClearPattern,
        action = act.Multiple({
          wez_tmux.action.ClearPattern,
          act.ClearSelection,
          act.CopyMode("ClearSelectionMode"),
        }),
      },
    })
  end
end

return M
