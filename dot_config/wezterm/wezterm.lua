-- https://github.com/folke/dot/blob/master/config/wezterm/wezterm.lua
-- https://github.com/chrisgrieser/.config/blob/main/wezterm/wezterm.lua

local wezterm = require("wezterm")
local act = wezterm.action
local config = wezterm.config_builder()

-- https://wezfurlong.org/wezterm/config/lua/config/index.html
-- Window
config.window_decorations = "RESIZE"
config.window_padding = { left = 0, right = 0, top = 0, bottom = 0 }

-- Tabs
-- config.enable_tab_bar = false
config.hide_tab_bar_if_only_one_tab = true

-- Colorscheme
config.color_scheme = "tokyonight_night"

-- Fonts
config.font = wezterm.font("JetBrainsMonoNL Nerd Font") -- wezterm ls-fonts --list-system
config.font_size = 13
-- config.cell_width = 0.9 -- effectively like letter-spacing

-- Cursor
-- config.force_reverse_video_cursor = true
-- config.underline_thickness = "0.07cell"
-- config.underline_position = -6
config.cursor_thickness = "0.07cell"

-- config.scrollback_lines = 10000

-- Mouse
config.mouse_bindings = {
	-- Right click to paste
	{
		event = { Down = { streak = 1, button = "Right" } },
		mods = "NONE",
		action = act.PasteFrom("PrimarySelection"),
	},

	-- Change the default click behavior so that it only selects text and doesn't open hyperlinks
	{
		event = { Up = { streak = 1, button = "Left" } },
		mods = "NONE",
		action = act.CompleteSelection("ClipboardAndPrimarySelection"),
	},
	-- And bind 'Up' event of SUPER-Click to open hyperlinks
	{
		event = { Up = { streak = 1, button = "Left" } },
		mods = "SUPER",
		action = act.CompleteSelectionOrOpenLinkAtMouseCursor("ClipboardAndPrimarySelection"),
	},
	-- Disable the 'Down' event of SUPER-Click to avoid weird program behaviors
	{
		event = { Down = { streak = 1, button = "Left" } },
		mods = "SUPER",
		action = act.Nop,
	},
}

return config
