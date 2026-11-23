--[[
vim_mode: leaving Vim insert mode switches Rime to ascii_mode, mirroring
Squirrel's vim_mode app option, which is implemented in its client:
  https://github.com/rime/squirrel/blob/b7970a93b05ae1ca1bcd97888fd6aa3cd0458d3e/sources/SquirrelInputController.swift#L414-L419

Squirrel does this itself: when Esc / Ctrl-C / Ctrl-[ is not consumed by Rime,
it sets ascii_mode. fcitx5-rime has no such client hook, so do it in a
processor: only act when no composition is in progress, and always return kNoop
so the key still reaches Rime and the application. Where Squirrel is the
frontend the processor stays out of the way, so the two do not duplicate.

Gated on the session option `vim_mode`, which the frontend sets per application:
Squirrel from `squirrel.custom.yaml` app_options, fcitx5-rime from `fcitx5.yaml`
app_options.
]] --
local kNoop = 2
local ESCAPE = 0xff1b

-- Squirrel implements vim_mode natively, so only the fcitx5-rime frontend needs
-- this processor. fcitx is identified by its per-user configuration directory,
-- honouring XDG_CONFIG_HOME.
local function is_fcitx_frontend()
  local home = os.getenv("HOME")
  if not home then
    return false
  end
  local config_home = os.getenv("XDG_CONFIG_HOME")
  if not config_home or config_home == "" then
    config_home = home .. "/.config"
  end
  -- The directory exists once fcitx5 has run; reading it is enough to tell.
  local probe = io.open(config_home .. "/fcitx5", "r")
  if not probe then
    return false
  end
  probe:close()
  return true
end

if not is_fcitx_frontend() then
  return function()
    return kNoop
  end
end

local function is_vim_normal_key(key)
  if key:release() then
    return false
  end
  if key.keycode == ESCAPE then
    return true
  end
  if key:ctrl() then
    local code = key.keycode
    return code == 99 or code == 67 or code == 91 -- c, C, [
  end
  return false
end

local function vim_mode(key, env)
  local context = env.engine.context
  -- Squirrel tests `!handled` after processing the key; a processor runs first,
  -- so "no composition in progress" is the closest equivalent for tiger, whose
  -- key bindings only consume Escape while composing.
  if
    context:get_option("vim_mode")
    and not context:get_option("ascii_mode")
    and not context:is_composing()
    and is_vim_normal_key(key)
  then
    context:set_option("ascii_mode", true)
  end
  return kNoop
end

return vim_mode
