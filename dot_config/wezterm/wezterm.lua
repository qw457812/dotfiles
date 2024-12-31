-- https://wezfurlong.org/wezterm/config/lua/config/index.html
--
-- https://github.com/folke/dot/blob/master/config/wezterm/wezterm.lua
-- https://github.com/chrisgrieser/.config/blob/main/wezterm/wezterm.lua
-- https://github.com/KevinSilvester/wezterm-config
--
-- TODO:
-- https://github.com/MLFlexer/resurrect.wezterm

local wezterm = require("wezterm") --[[@as Wezterm]]
-- wezterm.plugin.update_all() -- bad performance
local config = wezterm.config_builder()
wezterm.log_info("reloading")

require("mouse").apply_to_config(config)
require("links").apply_to_config(config)
require("keys").apply_to_config(config)

config.default_prog = { "/opt/homebrew/bin/fish", "-l" }

-- Window
config.window_decorations = "RESIZE"
config.window_padding = { left = 0, right = 0, top = 0, bottom = 0 }

-- Tabs
-- config.enable_tab_bar = false
config.hide_tab_bar_if_only_one_tab = true
-- wezterm.on("format-tab-title", function(tab)
--   local process = string.gsub(tab.active_pane.foreground_process_name, "(.*[/\\])(.*)", "%2")
--   local cwd = tab.active_pane.current_working_dir
--   cwd = cwd and string.format("%s ", cwd.file_path:gsub(os.getenv("HOME"), "~")) or ""
--   return string.format("(%d %s) %s", tab.tab_index + 1, process, cwd)
-- end)

-- Colorscheme
config.color_scheme = "tokyonight_night"
config.colors = {
  indexed = { [241] = "#65bcff" },
  -- https://github.com/folke/tokyonight.nvim/blob/19f39b53ef5e148bf94ea3696df36175af7e31e6/extras/wezterm/tokyonight_night.toml#L3
  background = "#1d1d1f", -- #1a1b26
}
config.window_background_image = os.getenv("HOME") .. "/.config/wall.png"
config.window_background_image_hsb = {
  brightness = 0.05,
}

-- Fonts
config.font = wezterm.font_with_fallback({
  "JetBrainsMono Nerd Font", -- "JetBrainsMonoNL Nerd Font", "FiraCode Nerd Font"
  -- Chinese
  "Maple Mono NF CN", -- "Sarasa Mono SC", "LXGW WenKai Mono"
}) -- wezterm ls-fonts --list-system
config.font_size = 13
config.command_palette_font_size = 15
-- config.cell_width = 0.9 -- effectively like letter-spacing

-- Cursor
-- config.force_reverse_video_cursor = true
-- config.underline_thickness = "0.07cell"
-- config.underline_position = -6
config.cursor_thickness = "0.07cell"

-- Scrollback
config.scrollback_lines = 50000

return config
