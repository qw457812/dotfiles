-- https://wezfurlong.org/wezterm/config/mouse.html#gotcha-on-binding-an-up-event-only

local wezterm = require("wezterm")
local keys = require("keys")
local act = wezterm.action

local M = {}

function M.apply_to_config(config)
  config.mouse_bindings = {
    -- Paste on right click
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
      mods = keys.super,
      action = act.CompleteSelectionOrOpenLinkAtMouseCursor("ClipboardAndPrimarySelection"),
    },
    -- Disable the 'Down' event of SUPER-Click to avoid weird program behaviors
    {
      event = { Down = { streak = 1, button = "Left" } },
      mods = keys.super,
      action = act.Nop,
    },
  }
end

return M
