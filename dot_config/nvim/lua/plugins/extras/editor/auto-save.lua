if lazyvim_docs then
  -- condition of auto-save.nvim
  vim.g.user_auto_save = false
end

local function cond(buf)
  return Snacks.util.var(buf, "user_auto_save", false)
end

return {
  {
    "okuuva/auto-save.nvim",
    event = { "LazyFile", "InsertEnter" },
    opts = function()
      -- copied from: https://github.com/AstroNvim/astrocommunity/blob/438fdb8c648bc8870bab82e9149cad595ddc7a67/lua/astrocommunity/editing-support/auto-save-nvim/init.lua
      local augroup = vim.api.nvim_create_augroup("auto_save_autoformat_toggle", { clear = true })
      vim.api.nvim_create_autocmd("User", {
        group = augroup,
        desc = "Disable autoformat before saving",
        pattern = "AutoSaveWritePre",
        callback = function()
          -- Save global autoformat status
          vim.g.OLD_AUTOFORMAT = vim.g.autoformat
          vim.g.autoformat = false

          local old_autoformat_buffers = {}
          -- Disable all manually enabled buffers
          for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
            if vim.b[bufnr].autoformat then
              table.insert(old_autoformat_buffers, bufnr)
              vim.b[bufnr].autoformat = false
            end
          end

          vim.g.OLD_AUTOFORMAT_BUFFERS = old_autoformat_buffers
        end,
      })
      vim.api.nvim_create_autocmd("User", {
        group = augroup,
        desc = "Re-enable autoformat after saving",
        pattern = "AutoSaveWritePost",
        callback = function()
          -- Restore global autoformat status
          vim.g.autoformat = vim.g.OLD_AUTOFORMAT
          -- Re-enable all manually enabled buffers
          for _, bufnr in ipairs(vim.g.OLD_AUTOFORMAT_BUFFERS or {}) do
            vim.b[bufnr].autoformat = true
          end
        end,
      })

      Snacks.toggle({
        name = "Auto Write",
        get = function()
          return vim.g.user_auto_save == true
        end,
        set = function(state)
          vim.g.user_auto_save = state
        end,
      }):map("<leader>uW")

      return {
        condition = cond,
      }
    end,
    specs = {
      {
        "nvim-lualine/lualine.nvim",
        optional = true,
        opts = function(_, opts)
          table.insert(opts.sections.lualine_x, 3, {
            function()
              return " " -- 󱑛 󱣪
            end,
            cond = cond,
            color = function()
              return { fg = Snacks.util.color(vim.bo.modified and "MatchParen" or "MiniIconsRed") }
            end,
          })
        end,
      },
    },
  },
}
