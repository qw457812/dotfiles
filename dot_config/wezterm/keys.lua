-- https://wezfurlong.org/wezterm/config/keys.html
-- https://wezfurlong.org/wezterm/config/lua/keyassignment/index.html

local wezterm = require("wezterm")
local helpers = require("helpers")
local act = wezterm.action

local M = {}

M.super = "SUPER"
M.leader = "LEADER"

local smart_split = wezterm.action_callback(function(win, pane)
	local dim = pane:get_dimensions()
	if dim.pixel_height > dim.pixel_width then
		win:perform_action(act.SplitVertical({ domain = "CurrentPaneDomain" }), pane)
	else
		win:perform_action(act.SplitHorizontal({ domain = "CurrentPaneDomain" }), pane)
	end
end)

local next_pane_or_tab_or_window = wezterm.action_callback(function(win, pane)
	local pane_count = #pane:tab():panes()
	local tab_count = #win:mux_window():tabs()
	if pane_count > 1 then
		win:perform_action(act.ActivatePaneDirection("Next"), pane)
	elseif tab_count > 1 then
		win:perform_action(act.ActivateTabRelative(1), pane)
	else
		win:perform_action(act.ActivateWindowRelative(1), pane)
	end
end)

local open_url = wezterm.action.QuickSelectArgs({
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
})

-- https://github.com/mrjones2014/smart-splits.nvim#wezterm
-- https://github.com/mrjones2014/smart-splits.nvim/blob/master/plugin/init.lua
-- Do *NOT* lazy-loading smart-splits.nvim
local function is_nvim(pane)
	-- this is set by the Neovim plugin on launch, and unset on ExitPre in Neovim
	return pane:get_user_vars().IS_NVIM == "true"
end

local function is_tmux(pane)
	-- https://wezfurlong.org/wezterm/shell-integration.html#user-vars
	-- require `source "/Applications/WezTerm.app/Contents/Resources/wezterm.sh"` in ~/.zshrc
	return pane:get_user_vars().WEZTERM_IN_TMUX == "1"
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
			if is_nvim(pane) or is_tmux(pane) then
				-- pass the keys through to nvim/tmux
				win:perform_action({ SendKey = { key = key, mods = mods } }, pane)
			else
				if resize_or_move == "resize" then
					win:perform_action({ AdjustPaneSize = { direction, resize_amount } }, pane)
				else
					-- local panes = pane:tab():panes_with_info()
					-- local is_zoomed = false
					-- for _, p in ipairs(panes) do
					-- 	if p.is_zoomed then
					-- 		is_zoomed = true
					-- 		break
					-- 	end
					-- end
					-- -- wezterm.log_info("is_zoomed: " .. tostring(is_zoomed))
					-- -- local dir = direction
					-- -- if is_zoomed then
					-- -- 	dir = (dir == "Up" or dir == "Left") and "Prev" or "Next"
					-- -- end
					-- -- wezterm.log_info("dir: " .. dir)
					-- -- win:perform_action({ ActivatePaneDirection = dir }, pane)
					win:perform_action({ ActivatePaneDirection = direction }, pane)
					-- if is_zoomed then
					-- 	win:perform_action({ SetPaneZoomState = is_zoomed }, pane)
					-- end
				end
			end
		end),
	}
end

function M.apply_to_config(config)
	-- -- tmux like
	-- config.leader = { key = "b", mods = "CTRL", timeout_milliseconds = 1000 }

	-- wezterm show-keys
	config.keys = {
		-- Send "CTRL-B" to the terminal when pressing CTRL-B, CTRL-B
		{ mods = "LEADER|CTRL", key = "b", action = act.SendKey({ key = "b", mods = "CTRL" }) },
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
		{ mods = M.super, key = "o", action = next_pane_or_tab_or_window },
		{ mods = M.super, key = "w", action = act.CloseCurrentPane({ confirm = false }) },
		-- Splits
		{ mods = M.super, key = "s", action = smart_split },
		{ mods = M.super, key = "\\", action = act.SplitHorizontal({ domain = "CurrentPaneDomain" }) },
		{ mods = M.leader, key = "\\", action = act.SplitHorizontal({ domain = "CurrentPaneDomain" }) },
		{ mods = M.super, key = "-", action = act.SplitVertical({ domain = "CurrentPaneDomain" }) },
		{ mods = M.leader, key = "-", action = act.SplitVertical({ domain = "CurrentPaneDomain" }) },
		{ mods = M.super, key = "z", action = act.TogglePaneZoomState },
		{ mods = M.leader, key = "z", action = act.TogglePaneZoomState },
		{ mods = M.super, key = "Enter", action = act.RotatePanes("Clockwise") },
		-- Tabs
		{ mods = M.super, key = "j", action = act({ ActivateTabRelative = 1 }) },
		{ mods = M.super, key = "k", action = act({ ActivateTabRelative = -1 }) },
		-- -- Scrollback
		-- { mods = M.super, key = "u", action = act.ScrollByPage(-0.5) },
		-- { mods = M.super, key = "d", action = act.ScrollByPage(0.5) },
		-- Others
		{ mods = M.super, key = "Space", action = act.ActivateCopyMode },
		{ mods = M.super, key = ":", action = act.ActivateCommandPalette },
		{ mods = M.super, key = "p", action = act.QuickSelect },
		{ mods = M.super, key = "d", action = act.ShowDebugOverlay },
		{ mods = M.super, key = "u", action = open_url },
		{ mods = M.super, key = "f", action = act.Search({ CaseInSensitiveString = "" }) },
	}

	config.key_tables = {}

	-- Copy Mode
	-- https://wezfurlong.org/wezterm/config/lua/wezterm.gui/default_key_tables.html
	if wezterm.gui then
		config.key_tables.copy_mode = helpers.list_extend(wezterm.gui.default_key_tables().copy_mode, {
			{ mods = "SHIFT", key = "H", action = act.CopyMode("MoveToStartOfLineContent") },
			{ mods = "SHIFT", key = "L", action = act.CopyMode("MoveToEndOfLineContent") },
			{ mods = "NONE", key = "u", action = act.CopyMode({ MoveByPage = -0.5 }) },
			{ mods = "NONE", key = "d", action = act.CopyMode({ MoveByPage = 0.5 }) },
			{ mods = "CTRL", key = "u", action = act.CopyMode({ MoveByPage = -0.5 }) },
			{ mods = "CTRL", key = "d", action = act.CopyMode({ MoveByPage = 0.5 }) },
			{ mods = "NONE", key = "/", action = act.Search({ CaseInSensitiveString = "" }) },
			{ mods = "NONE", key = "n", action = act.CopyMode("NextMatch") },
			{ mods = "SHIFT", key = "N", action = act.CopyMode("PriorMatch") },
		})
	end
end

return M
