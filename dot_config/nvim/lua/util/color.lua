---@class util.color
local M = {}

-- copied from:
-- https://github.com/folke/twilight.nvim/blob/1584c0b0a979b71fd86b18d302ba84e9aba85b1b/lua/twilight/util.lua
-- https://github.com/folke/tokyonight.nvim/blob/4b386e66a9599057587c30538d5e6192e3d1c181/lua/tokyonight/util.lua
-- https://github.com/catppuccin/nvim/blob/4fd72a9ab64b393c2c22b168508fd244877fec96/lua/catppuccin/utils/colors.lua

M.bg = "#000000"
M.fg = "#ffffff"

function M.hex2rgb(hex)
  hex = string.lower(hex)
  return tonumber(hex:sub(2, 3), 16), tonumber(hex:sub(4, 5), 16), tonumber(hex:sub(6, 7), 16)
end

function M.rgb2hex(r, g, b)
  return string.format("#%02x%02x%02x", r, g, b)
end

---@param hex string foreground color
---@param bg_hex string background color
---@param alpha number|string number between 0 and 1. 0 results in bg, 1 results in fg
function M.blend(hex, bg_hex, alpha)
  alpha = type(alpha) == "string" and (tonumber(alpha, 16) / 0xff) or alpha
  local fg = { M.hex2rgb(hex) }
  local bg = { M.hex2rgb(bg_hex) }

  local blendChannel = function(i)
    local ret = (alpha * fg[i] + ((1 - alpha) * bg[i]))
    return math.floor(math.min(math.max(0, ret), 255) + 0.5)
  end

  return M.rgb2hex(blendChannel(1), blendChannel(2), blendChannel(3))
end

function M.blend_bg(hex, amount, bg)
  return M.blend(hex, bg or M.bg, math.abs(amount))
end
-- function M.darken(hex, amount)
--   local r, g, b = M.hex2rgb(hex)
--   return M.rgb2hex(r * amount, g * amount, b * amount)
-- end
M.darken = M.blend_bg

function M.blend_fg(hex, amount, fg)
  return M.blend(hex, fg or M.fg, math.abs(amount))
end
M.lighten = M.blend_fg

function M.is_dark(hex)
  local r, g, b = M.hex2rgb(hex)
  -- Counting the perceptive luminance - human eye favors green color
  local luminance = (0.299 * r + 0.587 * g + 0.114 * b) / 255
  return luminance <= 0.5
end

function M.increase_saturation(hex, percentage)
  local rgb = { M.hex2rgb(hex) }

  local saturation_float = percentage

  table.sort(rgb)
  local rgb_intensity = {
    min = rgb[1] / 255,
    mid = rgb[2] / 255,
    max = rgb[3] / 255,
  }

  if rgb_intensity.max == rgb_intensity.min then
    -- all colors have same intensity, which means
    -- the original color is gray, so we can't change saturation.
    return hex
  end

  local new_intensities = {}
  new_intensities.max = rgb_intensity.max
  new_intensities.min = rgb_intensity.max * (1 - saturation_float)

  if rgb_intensity.mid == rgb_intensity.min then
    new_intensities.mid = new_intensities.min
  else
    local intensity_proportion = (rgb_intensity.max - rgb_intensity.mid) / (rgb_intensity.mid - rgb_intensity.min)
    new_intensities.mid = (intensity_proportion * new_intensities.min + rgb_intensity.max) / (intensity_proportion + 1)
  end

  for i, v in pairs(new_intensities) do
    new_intensities[i] = math.floor(v * 255)
  end
  table.sort(new_intensities)
  return (M.rgb2hex(new_intensities.max, new_intensities.min, new_intensities.mid))
end

---@param hex string
function M.to_gray(hex)
  if not hex or hex:upper() == "NONE" then
    return hex
  end

  local r, g, b = M.hex2rgb(hex)

  -- local avg = math.floor((r + g + b) / 3)
  -- return M.rgb2hex(avg, avg, avg)

  -- https://github.com/killitar/obscure.nvim/blob/0e61b96a2c8551e73f8520b1f086d63f50d71bbd/lua/obscure/palettes/obscure.lua#L2
  -- https://github.com/mellow-theme/mellow.nvim/blob/5c8b4eaadf190f646f201322f96f00140b6b1a0b/lua/mellow/colors.lua#L5
  local base_r, base_g, base_b = M.hex2rgb("#161617")
  return M.rgb2hex(
    math.floor(base_r / (base_r + base_g + base_b) * (r + g + b)),
    math.floor(base_g / (base_r + base_g + base_b) * (r + g + b)),
    math.floor(base_b / (base_r + base_g + base_b) * (r + g + b))
  )
end

return M
