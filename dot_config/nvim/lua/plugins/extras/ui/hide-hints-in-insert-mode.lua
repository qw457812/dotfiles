---@class AutoToggle.Opts
---@field get fun(event:vim.api.create_autocmd.callback.args):boolean
---@field set fun(state:boolean,event:vim.api.create_autocmd.callback.args)

---@param opts AutoToggle.Opts
local function auto_toggle(opts)
  local augroup = vim.api.nvim_create_augroup("hide_hints_in_insert_mode", { clear = false })

  local enabled
  vim.api.nvim_create_autocmd("InsertEnter", {
    group = augroup,
    callback = function(event)
      enabled = opts.get(event)
      if enabled then
        opts.set(false, event)
      end
    end,
  })
  vim.api.nvim_create_autocmd("InsertLeave", {
    group = augroup,
    callback = function(event)
      if enabled then
        opts.set(true, event)
      end
    end,
  })
end

-- https://github.com/aimuzov/LazyVimx/blob/0065ab3164be894a93fe364b5135a811376c0110/lua/lazyvimx/extras/ui/style/editor/hide-hints-in-insert-mode.lua
return {
  {
    "neovim/nvim-lspconfig",
    optional = true,
    opts = function()
      auto_toggle({
        get = function(event)
          return vim.lsp.inlay_hint.is_enabled({ bufnr = event.buf })
        end,
        set = function(state, event)
          vim.lsp.inlay_hint.enable(state, { bufnr = event.buf })
        end,
      })
    end,
  },

  {
    "nvim-treesitter/nvim-treesitter-context",
    optional = true,
    opts = function()
      local tsc = require("treesitter-context")

      auto_toggle({
        get = tsc.enabled,
        set = function(state)
          if state then
            tsc.enable()
          else
            tsc.disable()
          end
        end,
      })
    end,
  },

  {
    "echasnovski/mini.indentscope",
    optional = true,
    opts = function()
      auto_toggle({
        get = function()
          return not vim.b.miniindentscope_disable
        end,
        set = function(state)
          vim.b.miniindentscope_disable = not state
        end,
      })
    end,
  },

  {
    "lukas-reineke/indent-blankline.nvim",
    optional = true,
    opts = function()
      local ibl = require("ibl")
      local conf = require("ibl.config")

      auto_toggle({
        get = function(event)
          return conf.get_config(event.buf).enabled
        end,
        set = function(state, event)
          ibl.setup_buffer(event.buf, { enabled = state })
        end,
      })
    end,
  },

  {
    "lukas-reineke/virt-column.nvim",
    optional = true,
    opts = function()
      local vc = require("virt-column")
      local conf = require("virt-column.config")

      auto_toggle({
        get = function(event)
          return conf.get_config(event.buf).enabled
        end,
        set = function(state, event)
          vc.setup_buffer(event.buf, { enabled = state })
        end,
      })
    end,
  },

  {
    "Wansmer/symbol-usage.nvim",
    optional = true,
    opts = function()
      auto_toggle({
        get = function(event)
          return next(require("symbol-usage.state").get_buf_workers(event.buf)) ~= nil
        end,
        set = function(state, event)
          if state then
            require("symbol-usage.buf").attach_buffer(event.buf)
          else
            require("symbol-usage.buf").clear_buffer(event.buf)
          end
        end,
      })
    end,
  },
}
