-- dump-specs.lua
-- Emit, for every lazy.nvim plugin, the exact (installed, target) commits that
-- lazy itself uses to decide "outdated". An offline shell tool then only needs
-- `git log installed..target` — no re-implementation of get_target/Semver/etc.
--
-- Output: one TSV line per plugin:
--   name|pin|is_local|dir|url|skip|installed|target
--     pin       "true"/"false"  (p.pin)
--     is_local  "true"/"false"  (p._.is_local — dev/dir plugin)
--     dir       install directory
--     url       origin URL (lazy's Git.get_origin), for building issue/PR links
--     skip      "" | "pin" | "local" | "not-installed"
--               Mirrors checker.fast_check's skip conditions. (disabled/clean
--               plugins never enter lazy.plugins(), so never reach here.)
--     installed current HEAD commit from Git.info ("" if dir has no .git)
--     target    lazy's update target commit from Git.get_target ("" on error
--               or when get_target returns no commit)
--
-- installed/target are computed with lazy's OWN Git.info / Git.get_target, so
-- the comparison is identical to what :Lazy check / checker.fast_check do.
--
-- Output target:
--   If $LAZY_CHANGELOG_SPEC_FILE is set, writes the TSV there directly (this
--   is how refresh-specs.sh captures clean output — nvim's own stdout, e.g.
--   iTerm2 OSC 1337 escape sequences, is discarded so it can never pollute
--   the data). Otherwise writes to stdout for manual `:luafile` use.
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
local Util = require("lazy.util")

-- When $LAZY_CHANGELOG_SPEC_FILE is set, accumulate lines and write them in
-- one shot via Util.write_file (which truncates on open, so a single write).
-- This keeps nvim's stdout (iTerm2 OSC sequences, plugin chatter) out of the
-- data; refresh-specs.sh sets the env var and discards nvim stdout. Fall back
-- to stdout for manual `:luafile` use.
local out_path = os.getenv("LAZY_CHANGELOG_SPEC_FILE")
local out_lines = {}
local function emit(s)
  if out_path then
    out_lines[#out_lines + 1] = s
  else
    io.stdout:write(s)
  end
end

for _, p in ipairs(lazy.plugins()) do
  local name = p.name or "?"
  local pin = p.pin == true
  local is_local = (p._ and p._.is_local) == true
  local dir = p.dir or ""
  local url = ""

  local skip, installed, target = "", "", ""

  -- Mirror checker.fast_check: it only checks plugins that are installed AND
  -- not pin AND not local. Local plugins are user-managed (dev), pinned ones
  -- are frozen; both must be skipped or get_target would report spurious updates.
  if pin then
    skip = "pin"
  elseif is_local then
    skip = "local"
  elseif not (p._ and p._.installed) then
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

  -- origin URL for building github issue/PR links; reads the actual .git/config
  -- remote, so it's correct even when the spec URL differs from the clone.
  if dir ~= "" then
    local ok, origin = pcall(Git.get_origin, dir)
    if ok and origin then url = origin end
  end

  emit(string.format("%s|%s|%s|%s|%s|%s|%s|%s\n",
    name, tostring(pin), tostring(is_local),
    dir, url, skip, installed, target))
end

if out_path then
  Util.write_file(out_path, table.concat(out_lines))
end
