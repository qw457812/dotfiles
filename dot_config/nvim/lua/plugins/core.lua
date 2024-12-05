return {
  { "folke/lazy.nvim", version = false },
  { "LazyVim/LazyVim", version = false },
  {
    "folke/snacks.nvim",
    ---@module "snacks"
    ---@type snacks.Config
    opts = {
      notifier = {
        style = "fancy",
        -- top_down = false,
      },
      terminal = {
        win = {
          position = "float", -- alternative: style = "float"
        },
      },
    },
    init = function()
      LazyVim.on_very_lazy(function()
        _G.dd = function(...)
          Snacks.debug.inspect(...)
        end
        _G.bt = function()
          Snacks.debug.backtrace()
        end
        vim.print = _G.dd -- override print to use snacks for `:=` command
      end)
    end,
  },
}
