---@type LazySpec
return {
  -- learn
  {
    "folke/dot",
    name = "folke_dot",
    lazy = true,
    config = function() end,
    specs = {
      {
        "LazyVim/LazyVim",
        keys = {
          { "<leader>lf", "<cmd>Lazy log folke_dot<cr>", desc = "Folke Dot Logs" },
        },
      },
    },
  },

  -- fish
  {
    "neovim/nvim-lspconfig",
    ---@param opts PluginLspOpts
    opts = function(_, opts)
      local manpager = vim.env.MANPAGER
      local fish_lsp_manpager = vim.fn.executable("col") == 1 and "col -bx" or "cat"

      return U.extend_tbl(opts, {
        ---@type table<string, lazyvim.lsp.Config|boolean>
        servers = {
          fish_lsp = {
            -- failed to install on termux
            -- ksb_pastebuf of kitty-scrollback.nvim
            enabled = not (vim.g.user_is_termux or vim.g.terminal_scrollback_pager),
            cmd_env = {
              -- HACK: prevent `bob update --all` from failing with: `Error: Neovim is currently running. Please close it before updating.`
              -- see: https://github.com/ndonfris/fish-lsp/blob/1be77fcfa37d9d3877994f14163c7faacf7a533e/fish_files/get-documentation.fish
              -- work with the following MANPAGER in config.fish:
              -- ```fish
              -- if status is-interactive
              --     set -x MANPAGER 'nvim --cmd "lua vim.g.manpager = true" -c "nnoremap d <C-d>|lua vim.defer_fn(function() vim.api.nvim_command(\"silent! nunmap dd|nnoremap u <C-u>\") end, 500)" +Man!'
              -- end
              -- ```
              MANPAGER = fish_lsp_manpager,
            },
          },
        },
        setup = {
          fish_lsp = function()
            vim.api.nvim_create_autocmd("BufEnter", {
              group = vim.api.nvim_create_augroup("fix_fish_lsp_manpager", {}),
              desc = "Fix hover and blink documentation for fish-lsp",
              callback = function(ev)
                vim.env.MANPAGER = vim.bo[ev.buf].filetype == "fish" and fish_lsp_manpager or manpager
              end,
            })
          end,
        },
      } --[[@as PluginLspOpts]])
    end,
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
    opts = {
      formatters_by_ft = {
        zsh = { "shfmt" },
      },
    },
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
    ---@type lazyvim.TSConfig|{}
    opts = { ensure_installed = { "kitty" } },
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

      vim.treesitter.language.register("kitty", "kitty")
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
