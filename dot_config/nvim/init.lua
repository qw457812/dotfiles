_G.U = require("util")

_G.dd = function(...)
  require("snacks.debug").inspect(...)
end
_G.bt = function()
  require("snacks.debug").backtrace()
end
_G.p = function(...)
  require("snacks.debug").profile(...)
end
-- override print to use snacks for `:=` command
---@diagnostic disable-next-line: duplicate-set-field
vim._print = function(_, ...)
  dd(...)
end

-- bootstrap lazy.nvim, LazyVim and your plugins
require("config.lazy")
