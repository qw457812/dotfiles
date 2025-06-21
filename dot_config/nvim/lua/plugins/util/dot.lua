return {
  -- fish
  {
    "LazyVim/LazyVim",
    opts = function()
      if vim.g.user_is_termux then
        return
      end
      vim.api.nvim_create_autocmd("FileType", {
        pattern = "fish",
        callback = function()
          vim.lsp.start({
            name = "fish-lsp",
            cmd = { "fish-lsp", "start" },
            cmd_env = { fish_lsp_show_client_popups = false },
          })
        end,
      })
    end,
  },
  {
    "williamboman/mason.nvim",
    opts = vim.g.user_is_termux and {} or { ensure_installed = { "fish-lsp" } },
  },
  -- {
  --   "stevearc/conform.nvim",
  --   optional = true,
  --   opts = function(_, opts)
  --     if vim.g.user_is_termux then
  --       return
  --     end
  --     opts.formatters_by_ft = opts.formatters_by_ft or {}
  --     opts.formatters_by_ft.fish = nil -- using fish-lsp
  --   end,
  -- },

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

      -- fix `vim: true` in ~/.aider.conf.yml
      vim.api.nvim_create_autocmd("BufReadPre", {
        pattern = { ".aider.conf.yml", "dot_aider.conf.yml" },
        callback = function(event)
          -- vim.opt_local.modelines = 0
          vim.bo[event.buf].modeline = false
        end,
      })
      if LazyVim.has("chezmoi.vim") and vim.g["chezmoi#use_tmp_buffer"] == 1 then
        vim.g["chezmoi#detect_ignore_pattern"] = "dot_aider.conf.yml"
      end

      -- fix `Option 'commentstring' is empty.` sometimes occurs in kitty.conf
      vim.api.nvim_create_autocmd("FileType", {
        pattern = "kitty",
        callback = function()
          vim.opt_local.commentstring = "# %s"
        end,
      })
    end,
  },

  {
    "nvim-treesitter/nvim-treesitter",
    opts = function()
      vim.filetype.add({
        filename = {
          [".aider.model.metadata.json"] = "jsonc",
          ["dot_aider.model.metadata.json"] = "jsonc", -- chezmoi
        },
        pattern = {
          [".*/vscode/settings%.json"] = "jsonc",
          [".*/vscode/keybindings%.json"] = "jsonc",
        },
      })

      vim.treesitter.language.register("vim", "vifm")
      vim.api.nvim_create_autocmd("FileType", {
        pattern = "vifm",
        callback = function()
          vim.opt_local.commentstring = '" %s'
        end,
      })
    end,
  },
}
