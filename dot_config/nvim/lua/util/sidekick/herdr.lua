local Config = require("sidekick.config")
local Session = require("sidekick.cli.session")
local Util = require("sidekick.util")

---@class sidekick.cli.muxer.Herdr: sidekick.cli.Session
---@field herdr_terminal_id? string Stable identity; pane ids can be compacted/reused.
---@field herdr_pane_id? string
---@field herdr_workspace_id? string
local M = {}
M.__index = M

local LABEL_PREFIX = "sidekick:"

---@param args string[]
---@return string[]
function M.cmd(args)
  return vim.list_extend({ "herdr" }, args)
end

---@param args string[]
---@param required? boolean
---@return string?
function M.exec(args, required)
  local result = vim.system(M.cmd(args), { text = true }):wait(10000)
  if result.code == 0 then
    return result.stdout or ""
  end
  if required then
    error(("Herdr command failed: %s\n%s"):format(table.concat(args, " "), result.stderr or ""))
  end
end

---@param args string[]
---@param required? boolean
---@return table?
---@overload fun(args: string[], required: true): table
function M.json(args, required)
  local stdout = M.exec(args, required)
  local ok, response = pcall(vim.json.decode, stdout or "")
  if ok and type(response) == "table" and not response.error and type(response.result) == "table" then
    return response.result
  end
  if required then
    local detail = ok and type(response) == "table" and response.error and vim.json.encode(response.error)
      or stdout
      or "command failed"
    error(("Herdr request failed: %s\n%s"):format(table.concat(args, " "), detail))
  end
end

function M:init()
  if not self.started then
    self.external = vim.env.HERDR_ENV == "1" and Config.cli.mux.create ~= "terminal"
  end
  self.priority = self.external and 10 or 50
end

---@return table[]
function M.panes()
  local result = M.json({ "pane", "list" })
  return result and result.panes or {}
end

---@param pane table
function M:update_pane(pane)
  self.herdr_terminal_id = assert(pane.terminal_id, "Herdr did not return a terminal id")
  self.herdr_pane_id = assert(pane.pane_id, "Herdr did not return a pane id")
  self.herdr_workspace_id = pane.workspace_id
  self.mux_session = pane.workspace_id
  self.id = "herdr " .. self.herdr_terminal_id
  self.started = true
end

---@return string?
function M:pane_id()
  -- Never fall back to the old pane id: it may now refer to someone else's terminal.
  if self.herdr_terminal_id then
    for _, pane in ipairs(M.panes()) do
      if pane.terminal_id == self.herdr_terminal_id then
        self:update_pane(pane)
        return pane.pane_id
      end
    end
  end
end

function M:is_running()
  return self:pane_id() ~= nil
end

---@return sidekick.cli.terminal.Cmd?
function M:attach()
  if not self.external and self.herdr_terminal_id then
    -- Do not take over another Neovim's direct-attach client.
    return { cmd = M.cmd({ "terminal", "attach", self.herdr_terminal_id }) }
  end
end

---@return string
function M:command()
  local cmd = { "env" }
  for _, key in ipairs(vim.tbl_keys(self.tool.env or {})) do
    if self.tool.env[key] == false then
      vim.list_extend(cmd, { "-u", key })
    end
  end
  for key, value in pairs(self.tool.env or {}) do
    if value ~= false then
      cmd[#cmd + 1] = ("%s=%s"):format(key, tostring(value))
    end
  end
  -- `command` is a shell builtin, not an executable accepted by env.
  vim.list_extend(cmd, vim.list_slice(self.tool.cmd, self.tool.cmd[1] == "command" and 2 or 1))
  -- Herdr's creation CLI starts a shell. Replace it so tool exit closes the pane,
  -- like tmux new-session <command>, instead of leaving an idle shell behind.
  return "exec " .. table.concat(vim.tbl_map(vim.fn.shellescape, cmd), " ")
end

---@param pane_id string
---@return number
function M.split_ratio(pane_id)
  local split = Config.cli.mux.split
  local size = split.size
  if size > 1 then
    local result = M.json({ "pane", "layout", "--pane", pane_id }, true)
    local extent
    for _, pane in ipairs(result.layout.panes) do
      if pane.pane_id == pane_id then
        extent = split.vertical and pane.rect.width or pane.rect.height
        break
      end
    end
    size = size / math.max(assert(extent, "Herdr did not return the split target's geometry") - 1, 1)
  end
  -- Herdr's ratio measures the ORIGINAL pane, and is limited to 0.1..0.9.
  return math.max(0.1, math.min(0.9, 1 - size))
end

---@return sidekick.cli.terminal.Cmd?
function M:start()
  local cmd
  if self.external then
    local current = M.json({ "pane", "current" }, true)
    local pane = assert(current.pane, "Herdr did not return the current pane")
    if Config.cli.mux.create == "window" then
      cmd = { "tab", "create", "--workspace", pane.workspace_id, "--label", self.sid }
    else
      cmd = {
        "pane",
        "split",
        pane.pane_id,
        "--direction",
        Config.cli.mux.split.vertical and "right" or "down",
        "--ratio",
        tostring(M.split_ratio(pane.pane_id)),
      }
    end
  else
    cmd = { "workspace", "create", "--label", self.sid }
  end
  vim.list_extend(cmd, { "--cwd", self.cwd, "--no-focus" })
  local result = M.json(cmd, true)
  local pane = assert(result.pane or result.root_pane, "Herdr did not return the created pane")
  self:update_pane(pane)

  local ok, err = pcall(function()
    -- Persist ownership for discovery after restarting Neovim. Ordinary Herdr
    -- panes remain external, just like ordinary tmux windows/splits.
    M.json({ "pane", "rename", pane.pane_id, (self.external and "" or LABEL_PREFIX) .. self.sid }, true)
    M.exec({ "pane", "run", pane.pane_id, self:command() }, true)
  end)
  if not ok then
    self:close()
    self.started = false
    error(err)
  end
  if self.external then
    Util.info(("Started **%s** in a Herdr %s"):format(self.tool.name, Config.cli.mux.create))
  else
    return self:attach()
  end
end

function M:send(text)
  local function send()
    local pane_id = self:pane_id()
    if pane_id then
      -- Literal input, matching tmux paste-buffer -r (no automatic Enter).
      Util.exec(M.cmd({ "pane", "send-text", pane_id, text }))
    end
  end
  if self.tool.mux_focus then
    local pane_id = self:pane_id()
    if pane_id then
      Util.exec(M.cmd({ "pane", "send-text", pane_id, "\27[I" }))
      vim.defer_fn(send, 50)
    end
  else
    send()
  end
end

---@param keys string[] Herdr key names, e.g. ctrl+u or enter.
function M:send_keys(keys)
  local pane_id = self:pane_id()
  if pane_id then
    Util.exec(M.cmd(vim.list_extend({ "pane", "send-keys", pane_id }, keys)))
  end
end

function M:submit()
  self:send_keys({ "enter" })
end

function M:close()
  local pane_id = self:pane_id()
  if pane_id then
    M.json({ "pane", "close", pane_id }, true)
  end
end

function M:dump()
  local pane_id = self:pane_id()
  if pane_id then
    local _, text = Util.exec(
      M.cmd({
        "pane",
        "read",
        pane_id,
        "--source",
        "recent",
        "--lines",
        tostring(math.min(Config.cli.mux.dump, 1000)), -- Herdr's read limit
        "--ansi",
      }),
      { notify = false }
    )
    return text
  end
end

function M.sessions()
  local panes = M.panes()
  if #panes == 0 then
    return {}
  end
  local Procs = require("sidekick.cli.procs")
  local Terminal = require("sidekick.cli.terminal")
  local procs, tools = Procs.new(), Config.tools()
  local ret = {} ---@type sidekick.cli.session.State[]
  for _, pane in ipairs(panes) do
    local result = M.json({ "pane", "process-info", "--pane", pane.pane_id })
    local info = result and result.process_info
    if pane.terminal_id and info then
      local tool, cwd
      local pids = {} ---@type integer[]
      local function inspect(proc)
        pids[#pids + 1] = proc.pid
        if not tool then
          for _, candidate in pairs(tools) do
            if candidate:is_proc(proc) then
              tool, cwd = candidate, proc.cwd or pane.foreground_cwd or pane.cwd
              break
            end
          end
        end
      end
      -- Walk descendants as tmux does (shell/wrapper -> node -> agent).
      if info.shell_pid then
        procs:walk(info.shell_pid, inspect)
      end
      -- Herdr can expose foreground processes even when local ps is incomplete.
      for _, proc in ipairs(info.foreground_processes or {}) do
        inspect({
          pid = proc.pid,
          ppid = info.shell_pid or 0,
          cmd = proc.cmdline or (proc.argv and table.concat(proc.argv, " ")) or proc.argv0 or proc.name or "",
          cwd = proc.cwd,
        })
      end
      if tool then
        -- Sidekick uses overlapping pids to prefer the attached terminal (100)
        -- over this mux session (50), avoiding duplicate entries in its picker.
        for _, terminal in pairs(Terminal.terminals) do
          local parent = terminal.parent
          if terminal.mux_backend == "herdr" and parent then
            ---@cast parent sidekick.cli.muxer.Herdr
            if parent.herdr_terminal_id == pane.terminal_id then
              vim.list_extend(pids, terminal.pids or {})
            end
          end
        end
        cwd = cwd or Session.cwd()
        -- Agents can rewrite their process title (pi2 -> pi), losing the argv
        -- used by is_proc. After confirming a live tool, restore its configured
        -- identity from the label saved by start(), including external sessions.
        for _, candidate in pairs(tools) do
          local sid = Session.sid({ tool = candidate.name, cwd = cwd })
          if pane.label == LABEL_PREFIX .. sid or pane.label == sid then
            tool = candidate
            break
          end
        end
        ret[#ret + 1] = {
          id = "herdr " .. pane.terminal_id,
          tool = tool,
          cwd = cwd,
          external = pane.label ~= LABEL_PREFIX .. Session.sid({ tool = tool.name, cwd = cwd }),
          herdr_terminal_id = pane.terminal_id,
          herdr_pane_id = pane.pane_id,
          herdr_workspace_id = pane.workspace_id,
          mux_session = pane.workspace_id,
          pids = pids,
        }
      end
    end
  end
  return ret
end

return M
