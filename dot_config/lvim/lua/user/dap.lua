-- https://github.com/abzcoding/lvim/blob/main/lua/user/dap.lua
local M = {}

M.config = function()
  local status_ok, dap = pcall(require, "dap")
  if not status_ok then
    return
  end

  --Java debugger adapter settings
  dap.configurations.java = {
    -- {
    --   name = "Debug (Attach) - Remote",
    --   type = "java",
    --   request = "attach",
    --   hostName = "127.0.0.1",
    --   port = 5005,
    -- },
    {
      name = "Debug Non-Project class",
      type = "java",
      request = "launch",
      program = "${file}",
    },
  }
end

return M
