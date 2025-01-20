return {
  -- zsh
  {
    "stevearc/conform.nvim",
    optional = true,
    opts = function(_, opts)
      opts.formatters_by_ft = opts.formatters_by_ft or {}
      opts.formatters_by_ft.zsh = { "shfmt" }
    end,
  },
  {
    "williamboman/mason.nvim",
    opts = { ensure_installed = { "shfmt" } },
  },

  {
    "LazyVim/LazyVim",
    opts = function()
      -- https://github.com/yqrashawn/GokuRakuJoudo
      vim.api.nvim_create_autocmd("BufRead", {
        pattern = "karabiner.edn",
        callback = function(event)
          vim.b[event.buf].autoformat = false
        end,
      })
      if vim.fn.executable("goku") == 1 then
        vim.api.nvim_create_autocmd("BufWritePost", {
          pattern = "karabiner.edn",
          -- wait till "chezmoi apply" done
          callback = U.debounce_wrap(500, function()
            local res = vim.system({ "goku" }, { text = true }):wait()
            if res.code == 0 then
              LazyVim.info("karabiner.json updated", { title = "Goku" })
            else
              LazyVim.error(("Failed to run `goku`:\n%s"):format(res.stderr), { title = "Goku" })
            end
          end),
        })
      end
    end,
  },

  {
    "nvim-treesitter/nvim-treesitter",
    opts = function()
      vim.treesitter.language.register("vim", "vifm")
    end,
  },
}
