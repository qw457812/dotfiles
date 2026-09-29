-- Loaded only inside MiniTest's disposable child Neovim.
return function(root)
  local F = { calls = {}, panes = {}, processes = {}, terminals = {}, system = vim.system }
  vim.env.HERDR_ENV = nil

  function F.pane(id, terminal)
    return { pane_id = id, terminal_id = terminal, workspace_id = "workspace-1", cwd = "/project" }
  end

  F.tools = {
    pi = {
      name = "pi",
      is_proc = function(_, proc)
        return proc.cmd == "pi --no-session"
      end,
    },
  }
  F.config = {
    cli = { mux = { create = "terminal", split = { vertical = true, size = 0.3 }, dump = 10000 } },
    tools = function()
      return F.tools
    end,
  }
  package.loaded["sidekick.config"] = F.config
  package.loaded["sidekick.cli.session"] = {
    cwd = function()
      return "/project"
    end,
    sid = function(opts)
      return opts.tool .. "@" .. opts.cwd
    end,
  }
  package.loaded["sidekick.cli.terminal"] = { terminals = F.terminals }
  package.loaded["sidekick.cli.procs"] = {
    new = function()
      return {
        walk = function(_, pid, cb)
          for _, proc in ipairs(F.processes[pid] or {}) do
            cb(proc)
          end
        end,
      }
    end,
  }
  package.loaded["sidekick.util"] = {
    info = function() end,
    exec = function(cmd)
      local result = vim.system(cmd):wait()
      if result.code == 0 then
        return {}, result.stdout
      end
    end,
  }

  F.respond = function(cmd)
    if cmd[2] == "workspace" and cmd[3] == "create" or cmd[2] == "tab" and cmd[3] == "create" then
      F.panes = { F.pane("pane-2", "term-stable") }
      return { root_pane = F.panes[1] }
    elseif cmd[3] == "split" then
      F.panes = { F.pane("pane-2", "term-stable") }
      return { pane = F.panes[1] }
    elseif cmd[3] == "current" then
      return { pane = F.pane("pane-1", "term-parent") }
    elseif cmd[3] == "list" then
      return { panes = F.panes }
    elseif cmd[3] == "process-info" then
      return { process_info = { shell_pid = 10, foreground_processes = {} } }
    elseif cmd[3] == "layout" then
      return { layout = { panes = { { pane_id = "pane-1", rect = { width = 101, height = 51 } } } } }
    end
    return {}
  end
  vim.system = function(cmd)
    F.calls[#F.calls + 1] = vim.deepcopy(cmd)
    local result, code, raw = F.respond(cmd)
    return {
      wait = function()
        return { code = code or 0, stdout = raw or vim.json.encode({ result = result }), stderr = "test error" }
      end,
    }
  end

  F.H = dofile(root .. "/lua/util/sidekick/herdr.lua")
  function F.new_session()
    local s = setmetatable({
      sid = "pi@/project",
      cwd = "/project",
      tool = { name = "pi", cmd = { "pi", "--no-session" }, env = {} },
    }, F.H)
    s:init()
    return s
  end
  return F
end
