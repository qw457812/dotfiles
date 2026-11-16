-- https://github.com/rawnly/smart-splits-backend-rex/blob/68f54325975ad47b03a968a3f201081bfadc0ff5/README.md?plain=1#L93-L106

local smart_splits = os.getenv("HOME")
  .. "/.local/share/nvim/lazy/smart-splits-backend-rex/rex/lua/smart-splits-rex/init.lua"
local ok, err = pcall(function()
  dofile(smart_splits).setup()
end)
if ok then
  for key, direction in pairs({ h = "left", j = "down", k = "up", l = "right" }) do
    rex.bind("ctrl+" .. key, "smart_splits_focus", { direction = direction, key = "ctrl+" .. key })
  end
else
  rex.log("warn", "smart-splits-backend-rex not loaded: " .. tostring(err))
end
