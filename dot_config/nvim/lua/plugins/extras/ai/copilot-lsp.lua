return {
  {
    "copilotlsp-nvim/copilot-lsp",
    event = "LazyFile",
    keys = {
      {
        "<tab>",
        function()
          local nes = require("copilot-lsp.nes")
          local _ = nes.walk_cursor_start_edit()
            or (nes.apply_pending_nes() and nes.walk_cursor_end_edit())
            or vim.cmd("wincmd w")
        end,
        desc = "Jump/Apply Suggestion or Next Window (Copilot LSP)",
      },
    },
    init = function()
      vim.g.copilot_nes_debounce = 500
      vim.lsp.enable("copilot_ls")
    end,
    specs = {
      { "zbirenbaum/copilot.lua", optional = true, enabled = false },
      {
        "williamboman/mason.nvim",
        opts = { ensure_installed = { "copilot-language-server" } },
      },
    },
  },

  {
    "nvim-lualine/lualine.nvim",
    optional = true,
    opts = function(_, opts)
      table.insert(
        opts.sections.lualine_x,
        2,
        LazyVim.lualine.status(LazyVim.config.icons.kinds.Copilot, function()
          local clients = package.loaded["copilot-lsp.nes"]
              and LazyVim.lsp.get_clients({ name = "copilot_ls", bufnr = 0 })
            or {}
          if #clients > 0 then
            return vim.b.nes_state and "pending" or "ok"
          end
        end)
      )
    end,
  },
}
