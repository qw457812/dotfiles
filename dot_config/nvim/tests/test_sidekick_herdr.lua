local eq = MiniTest.expect.equality
local expect_error = MiniTest.expect.error
local child = MiniTest.new_child_neovim()
local root = vim.fs.dirname(vim.fs.dirname(vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p")))

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      child.restart({ "-u", "NONE" })
      child.lua([[local root = ...; F = dofile(root .. "/tests/helpers/sidekick_herdr.lua")(root)]], { root })
    end,
    post_once = child.stop,
  },
})

T["terminal creates an owned workspace and attaches without takeover"] = function()
  child.lua("s = F.new_session(); attach = s:start()")
  eq(child.lua_get("s.priority"), 50)
  eq(child.lua_get("F.calls[1]"), {
    "herdr",
    "workspace",
    "create",
    "--label",
    "pi@/project",
    "--cwd",
    "/project",
    "--no-focus",
  })
  eq(child.lua_get("F.calls[2]"), { "herdr", "pane", "rename", "pane-2", "sidekick:pi@/project" })
  eq(child.lua_get("F.calls[3][3]"), "run")
  eq(child.lua_get("F.calls[3][5]:sub(1, 5)"), "exec ")
  eq(child.lua_get("attach.cmd"), { "herdr", "terminal", "attach", "term-stable" })
  eq(child.lua_get("s.id"), "herdr term-stable")
end

T["window creates an external tab in the caller workspace"] = function()
  child.lua([[vim.env.HERDR_ENV = "1"; F.config.cli.mux.create = "window"; s = F.new_session()]])
  eq(child.lua_get("s.priority"), 10)
  eq(child.lua_get("s:start()"), vim.NIL)
  eq(child.lua_get("F.calls[2]"), {
    "herdr",
    "tab",
    "create",
    "--workspace",
    "workspace-1",
    "--label",
    "pi@/project",
    "--cwd",
    "/project",
    "--no-focus",
  })
  eq(child.lua_get("s:attach()"), vim.NIL)
end

T["split uses the caller pane and reverses the new pane fraction"] = function()
  child.lua([[vim.env.HERDR_ENV = "1"; F.config.cli.mux.create = "split"; F.new_session():start()]])
  eq(child.lua_get("F.calls[2]"), {
    "herdr",
    "pane",
    "split",
    "pane-1",
    "--direction",
    "right",
    "--ratio",
    "0.7",
    "--cwd",
    "/project",
    "--no-focus",
  })
end

T["absolute horizontal split size uses pane geometry"] = function()
  child.lua("F.config.cli.mux.split = { vertical = false, size = 20 }")
  eq(child.lua_get([[F.H.split_ratio("pane-1")]]), 0.6)
end

T["outside Herdr window mode falls back to an embedded terminal"] = function()
  child.lua([[F.config.cli.mux.create = "window"]])
  eq(child.lua_get("F.new_session():start().cmd"), { "herdr", "terminal", "attach", "term-stable" })
end

T["command preserves argv and supports empty and unset environment variables"] = function()
  child.lua([=[
    local s = F.new_session()
    s.tool.cmd = {
      "command", "sh", "-c",
      'printf "%s|%s|%s|%s" "$SET" "${EMPTY+x}:$EMPTY" "${REMOVE+x}" "$1"',
      "sh", "a ' quote\nand $text",
    }
    s.tool.env = { SET = "with ' quotes $dollar", EMPTY = "", REMOVE = false }
    result = F.system({ "sh", "-c", s:command() }, { text = true, env = { REMOVE = "inherited" } }):wait()
  ]=])
  eq(child.lua_get("result.code"), 0)
  eq(child.lua_get("result.stdout"), "with ' quotes $dollar|x:||a ' quote\nand $text")
end

T["pane id reuse never redirects input or close to another terminal"] = function()
  child.lua([[
    s = F.new_session()
    s:update_pane(F.pane("pane-1", "term-stable"))
    F.panes = { F.pane("pane-1", "term-other"), F.pane("pane-9", "term-stable") }
    s:send("--literal\ntext")
  ]])
  eq(child.lua_get("F.calls[#F.calls]"), { "herdr", "pane", "send-text", "pane-9", "--literal\ntext" })
  child.lua("s:submit()")
  eq(child.lua_get("F.calls[#F.calls]"), { "herdr", "pane", "send-keys", "pane-9", "enter" })
  child.lua([[F.panes = { F.pane("pane-9", "term-other") }; F.calls = {}; s:close()]])
  eq(child.lua_get("F.calls"), { { "herdr", "pane", "list" } })
  eq(child.lua_get("s:is_running()"), false)
end

T["dump requests ANSI text within Herdr's limit"] = function()
  child.lua([[
    local s = F.new_session()
    s:update_pane(F.pane("pane-2", "term-stable"))
    F.panes = { F.pane("pane-2", "term-stable") }
    s:dump()
  ]])
  eq(child.lua_get("F.calls[#F.calls]"), {
    "herdr",
    "pane",
    "read",
    "pane-2",
    "--source",
    "recent",
    "--lines",
    "1000",
    "--ansi",
  })
end

T["discovery walks wrappers and includes attach client pids for deduplication"] = function()
  child.lua([[
    F.panes = { F.pane("pane-2", "term-stable") }
    F.panes[1].label = "sidekick:pi@/project"
    F.processes[10] = {
      { pid = 10, cmd = "wrapper" },
      { pid = 11, cmd = "pi --no-session", cwd = "/project" },
    }
    F.terminals.one = { mux_backend = "herdr", parent = { herdr_terminal_id = "term-stable" }, pids = { 20 } }
    sessions = F.H.sessions()
  ]])
  eq(child.lua_get("#sessions"), 1)
  eq(child.lua_get("sessions[1].external"), false)
  eq(child.lua_get("sessions[1].pids"), { 10, 11, 20 })
  eq(child.lua_get("sessions[1].id"), "herdr term-stable")
  child.lua("F.panes[1].label = nil")
  eq(child.lua_get("F.H.sessions()[1].external"), true)
  child.lua([[F.processes[10] = { { pid = 10, cmd = "shell" } }]])
  eq(child.lua_get("F.H.sessions()"), {})
end

T["discovery preserves configured tool identities after process title changes"] = MiniTest.new_set({
  parametrize = { { "pi2", false }, { "pi2", true }, { "pi_tmp", false } },
})

T["discovery preserves configured tool identities after process title changes"]["uses the persisted label"] = function(
  name,
  external
)
  child.lua(
    [[
    local name, external = ...
    F.tools[name] = { name = name, is_proc = function(_, proc) return proc.cmd == name end }
    F.panes = { F.pane("pane-2", "term-stable") }
    F.panes[1].label = (external and "" or "sidekick:") .. name .. "@/project"
    F.processes[10] = { { pid = 10, cmd = "pi --no-session", cwd = "/project" } }
    F.terminals.one = { mux_backend = "herdr", parent = { herdr_terminal_id = "term-stable" }, pids = { 20 } }
    sessions = F.H.sessions()
  ]],
    { name, external }
  )
  eq(child.lua_get("#sessions"), 1)
  eq(child.lua_get("sessions[1].tool.name"), name)
  eq(child.lua_get("sessions[1].external"), external)
  eq(child.lua_get("sessions[1].pids"), { 10, 20 })

  -- A persisted label alone must not resurrect a tool that exited to a shell.
  child.lua([[F.processes[10] = { { pid = 10, cmd = "shell" } }]])
  eq(child.lua_get("F.H.sessions()"), {})
end

T["unknown labels do not override process discovery"] = function()
  child.lua([[
    F.panes = { F.pane("pane-2", "term-stable") }
    F.panes[1].label = "sidekick:missing@/project"
    F.processes[10] = { { pid = 10, cmd = "pi --no-session", cwd = "/project" } }
  ]])
  eq(child.lua_get("F.H.sessions()[1].tool.name"), "pi")
  eq(child.lua_get("F.H.sessions()[1].external"), true)
end

T["foreground process metadata works without local ps"] = function()
  child.lua([[
    F.panes = { F.pane("pane-2", "term-stable") }
    local original = F.respond
    F.respond = function(cmd)
      if cmd[3] == "process-info" then
        return { process_info = { foreground_processes = { { pid = 42, argv = { "pi", "--no-session" } } } } }
      end
      return original(cmd)
    end
  ]])
  eq(child.lua_get("F.H.sessions()[1].tool.name"), "pi")
end

T["failed run cleans up only the created pane and propagates stderr"] = function()
  child.lua([[
    local original = F.respond
    F.respond = function(cmd)
      if cmd[3] == "run" then return nil, 1 end
      return original(cmd)
    end
    s = F.new_session()
  ]])
  expect_error(function()
    child.lua("s:start()")
  end, "test error")
  eq(child.lua_get("F.calls[#F.calls]"), { "herdr", "pane", "close", "pane-2" })
  eq(child.lua_get("s.started"), false)
end

T["run accepts empty stdout and JSON parsing rejects malformed replies"] = function()
  child.lua([[F.respond = function() return nil, 0, "" end]])
  eq(child.lua_get([[F.H.exec({ "pane", "run", "pane-2", "exec pi" }, true)]]), "")
  eq(child.lua_get([[F.H.json({ "pane", "list" })]]), vim.NIL)
  expect_error(function()
    child.lua([[F.H.json({ "pane", "list" }, true)]])
  end, "Herdr request failed")
end

return T
