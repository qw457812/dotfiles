-- https://github.com/smart-splits-nvim/backend-wezterm/blob/54ec5bf0e0dfd1adf9698fbc883e458df312ec59/README.md

local wezterm = require("wezterm") --[[@as Wezterm]]

-- commit: ae840db696791f638c190c3e0534d2ddfcd5e6a7
local smart_splits = wezterm.plugin.require("https://github.com/smart-splits-nvim/backend-wezterm")

local M = {}

-- Keep keys.lua's tmux/fzf passthrough while registering the backend protocol.
function M.apply_to_config(config)
  local keys = config.keys
  config.keys = {}
  smart_splits.apply_to_config(config)
  config.keys = keys
end

return M
