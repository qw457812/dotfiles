local eq = MiniTest.expect.equality
local T = MiniTest.new_set()
local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h") .. "/lua/"
local path = root .. "plugins/remote.lua"

-- Evaluate the spec with isolated startup signals and lazy options. In
-- particular, v:startreason is read-only in a real Neovim process.
local function load_remote(appname, startreason)
  local config = {
    options = {
      checker = { enabled = true },
      change_detection = { enabled = true },
      defaults = {},
    },
  }
  local globals = {}
  local chunk = assert(loadfile(path))
  setfenv(
    chunk,
    setmetatable({
      vim = {
        env = { NVIM_APPNAME = appname },
        v = { startreason = startreason },
        g = globals,
        tbl_contains = vim.tbl_contains,
      },
      require = function(name)
        assert(name == "lazy.core.config", name)
        return config
      end,
    }, { __index = _G })
  )
  return chunk(), config.options, globals
end

T["ordinary startup is unchanged"] = function()
  for _, reason in ipairs({ "", "restart", "restart!" }) do
    local specs, options, globals = load_remote("nvim", reason)
    eq(specs, {})
    eq(options.checker.enabled, true)
    eq(options.change_detection.enabled, true)
    eq(options.defaults.cond, nil)
    eq(globals.snacks_animate, nil)
  end
end

T["older Neovim without startreason is supported"] = function()
  local specs, options = load_remote(nil, nil)
  eq(specs, {})
  eq(options.defaults.cond, nil)
end

T["either startup signal enables remote mode"] = function()
  for _, signals in ipairs({ { "nvim-remote", "" }, { "nvim", "remote-ssh" }, { "nvim-remote", "restart" } }) do
    local specs, options, globals = load_remote(unpack(signals))
    eq(#specs > 0, true)
    eq(options.checker.enabled, false)
    eq(options.change_detection.enabled, false)
    eq(globals.snacks_animate, false)
    local cond = options.defaults.cond
    for _, name in ipairs({ "LazyVim", "lazy.nvim", "snacks.nvim", "tokyonight.nvim" }) do
      eq(not not cond({ name = name }), true)
    end
    eq(not not cond({ name = "new-local-plugin.nvim" }), false)
    eq(not not cond({ name = "opt-in.nvim", remote = true }), true)
    eq(not not cond({ name = "pager-only.nvim", pager = true }), false)
    eq(not not cond({ name = "vscode-only.nvim", vscode = true }), false)
  end
end

return T
