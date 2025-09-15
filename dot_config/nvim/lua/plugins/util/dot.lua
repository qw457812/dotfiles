---@type LazySpec
return {
  -- fish
  {
    "LazyVim/LazyVim",
    opts = function()
      if
        vim.g.terminal_scrollback_pager -- ksb_pastebuf of kitty-scrollback.nvim
        or vim.g.user_is_termux
      then
        return -- fish-lsp failed to start
      end

      -- HACK: prevent `bob update --all` from failing with: `Error: Neovim is currently running. Please close it before updating.`
      -- see: https://github.com/ndonfris/fish-lsp/blob/1be77fcfa37d9d3877994f14163c7faacf7a533e/fish_files/get-documentation.fish
      -- work with the following MANPAGER in config.fish:
      -- ```fish
      -- if status is-interactive
      --     set -x MANPAGER 'nvim --cmd "lua vim.g.manpager = true" -c "nnoremap d <C-d>|lua vim.defer_fn(function() vim.api.nvim_command(\"silent! nunmap dd|nnoremap u <C-u>\") end, 500)" +Man!'
      -- end
      -- ```
      local manpager = vim.env.MANPAGER
      local fish_lsp_manpager = vim.fn.executable("col") == 1 and "col -bx" or "cat"
      vim.api.nvim_create_autocmd("FileType", {
        pattern = "fish",
        callback = function()
          vim.lsp.start({
            name = "fish-lsp",
            cmd = { "fish-lsp", "start" },
            cmd_env = {
              MANPAGER = fish_lsp_manpager,
              fish_lsp_show_client_popups = false,
            },
          })
        end,
      })
      vim.api.nvim_create_autocmd("BufEnter", {
        group = vim.api.nvim_create_augroup("fix_fish_lsp_manpager", {}),
        desc = "Fix hover and blink documentation for fish-lsp",
        callback = function(ev)
          vim.env.MANPAGER = vim.bo[ev.buf].filetype == "fish" and fish_lsp_manpager or manpager
        end,
      })
    end,
  },
  {
    "mason-org/mason.nvim",
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
    "mason-org/mason.nvim",
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
      if vim.g.user_is_kitty then
        vim.api.nvim_create_autocmd("BufWritePost", {
          pattern = "kitty.conf",
          callback = U.debounce_wrap(500, function()
            local res = vim.system({ "kitten", "@", "load-config" }, { text = true }):wait()
            if res.code == 0 then
              LazyVim.info("kitty.conf reloaded", { title = "Kitty" })
            else
              LazyVim.error(("Failed to run `kitten @ load-config`:\n%s"):format(res.stderr), { title = "Kitty" })
            end
          end),
        })
      end
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
