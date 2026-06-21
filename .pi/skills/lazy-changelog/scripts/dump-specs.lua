-- dump-specs.lua
-- Emit, for every lazy.nvim plugin, the exact (installed, target) commits that
-- lazy itself uses to decide "outdated". An offline shell tool then only needs
-- `git log installed..target` — no re-implementation of get_target/Semver/etc.
--
-- Output: one TSV line per plugin:
--   name|enabled|pin|is_local|dir|skip|installed|target
--     enabled   "true"/"false" (already evaluated; fun() resolved to bool)
--     pin       "true"/"false"
--     is_local  "true"/"false" (plugin._.is_local — dev/dir plugin)
--     dir       install directory
--     skip      reason string when this plugin is never an update candidate:
--               "" | "disabled" | "pin" | "local" | "not-installed"
--     installed current HEAD commit (or "" if dir has no .git)
--     target    lazy's update target commit from Git.get_target (or "" on
--               error / when get_target returns no commit)
--
-- installed/target are computed with lazy's OWN Git.info / Git.get_target, so
-- the comparison is identical to what :Lazy check / checker.fast_check do.
--
-- Usage (headless, via refresh-specs.sh):
--   nvim --headless +"lua require('lazy')" +"luafile /path/dump-specs.lua" +qa
-- If lazy is lazy-loaded, just open your config first then :luafile it.

local lazy_ok, lazy = pcall(require, "lazy")
if not lazy_ok or not lazy then
  io.stderr:write("dump-specs.lua: require('lazy') failed — run inside nvim with your config loaded\n")
  return
end
local Git = require("lazy.manage.git")

for _, p in ipairs(lazy.plugins()) do
  local name = p.name or "?"
  -- Resolved plugin object: p.enabled may be nil/true/false/fun (the raw spec
  -- value), so we must NOT treat nil as disabled. The authoritative signal is
  -- p._.kind == "disabled" (set during spec resolution). p.pin is already the
  -- resolved boolean. p._.is_local marks dev/dir plugins.
  local disabled = (p._ and p._.kind) == "disabled"
  local pin = p.pin == true
  local is_local = (p._ and p._.is_local) == true
  local installed_flag = (p._ and p._.installed) == true
  local dir = p.dir or ""
  local url = ""

  local skip, installed, target = "", "", ""

  if disabled then
    skip = "disabled"
  elseif pin then
    skip = "pin"
  elseif is_local then
    skip = "local"
  elseif not installed_flag then
    skip = "not-installed"
  else
    local info_ok, info = pcall(Git.info, dir)
    if info_ok and info and info.commit then
      installed = info.commit
    end
    local tok, tgt = pcall(Git.get_target, p)
    if tok and tgt and tgt.commit then
      target = tgt.commit
    end
  end

  -- origin URL for building github issue/PR links; works even for custom spec
  -- URLs since it reads the actual .git/config remote.
  if dir ~= "" then
    local ok, origin = pcall(Git.get_origin, dir)
    if ok and origin then url = origin end
  end

  io.stdout:write(string.format("%s|%s|%s|%s|%s|%s|%s|%s|%s\n",
    name, tostring(not disabled), tostring(pin), tostring(is_local),
    dir, url, skip, installed, target))
end
