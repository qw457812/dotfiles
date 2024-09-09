---@class util.color
local M = {}

M.bg = "#000000"
M.fg = "#ffffff"

---@param c  string
local function rgb(c)
  c = string.lower(c)
  return { tonumber(c:sub(2, 3), 16), tonumber(c:sub(4, 5), 16), tonumber(c:sub(6, 7), 16) }
end

--- copied from: https://github.com/folke/tokyonight.nvim/blob/4b386e66a9599057587c30538d5e6192e3d1c181/lua/tokyonight/util.lua#L30
---@param foreground string foreground color
---@param background string background color
---@param alpha number|string number between 0 and 1. 0 results in bg, 1 results in fg
function M.blend(foreground, alpha, background)
  alpha = type(alpha) == "string" and (tonumber(alpha, 16) / 0xff) or alpha
  local bg = rgb(background)
  local fg = rgb(foreground)

  local blendChannel = function(i)
    local ret = (alpha * fg[i] + ((1 - alpha) * bg[i]))
    return math.floor(math.min(math.max(0, ret), 255) + 0.5)
  end

  return string.format("#%02x%02x%02x", blendChannel(1), blendChannel(2), blendChannel(3))
end

function M.darken(hex, amount, bg)
  return M.blend(hex, amount, bg or M.bg)
end

function M.lighten(hex, amount, fg)
  return M.blend(hex, amount, fg or M.fg)
end

---@param hex string
function M.to_neutral_gray(hex)
  local r, g, b = unpack(rgb(hex))

  -- local avg = math.floor((r + g + b) / 3)
  -- return string.format("#%02x%02x%02x", avg, avg, avg)

  -- https://github.com/killitar/obscure.nvim/blob/0e61b96a2c8551e73f8520b1f086d63f50d71bbd/lua/obscure/palettes/obscure.lua#L2
  -- https://github.com/mellow-theme/mellow.nvim/blob/5c8b4eaadf190f646f201322f96f00140b6b1a0b/lua/mellow/colors.lua#L5
  local base_r, base_g, base_b = unpack(rgb("#161617"))
  return string.format(
    "#%02x%02x%02x",
    math.floor(base_r / (base_r + base_g + base_b) * (r + g + b)),
    math.floor(base_g / (base_r + base_g + base_b) * (r + g + b)),
    math.floor(base_b / (base_r + base_g + base_b) * (r + g + b))
  )
end

return M
