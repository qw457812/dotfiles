---@type LazySpec
return {
  -- learn
  { "folke/dot", name = "folke-dot", lazy = true, config = function() end },
  { "craftzdog/dotfiles", name = "craftzdog-dotfiles", lazy = true, config = function() end },

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
            -- ksb_pastebuf of kitty-scrollback.nvim
            enabled = not vim.g.terminal_scrollback_pager,
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
  {
    "stevearc/conform.nvim",
    optional = true,
    opts = function(_, opts)
      opts.formatters_by_ft = opts.formatters_by_ft or {}
      opts.formatters_by_ft.fish = nil -- using fish-lsp
    end,
  },

  -- zsh
  {
    "nvim-treesitter/nvim-treesitter",
    ---@type lazyvim.TSConfig|{}
    opts = { ensure_installed = { "zsh" } },
  },
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

      if vim.g.user_is_asahi and vim.fn.executable("systemctl") == 1 and vim.fn.executable("kanata") == 1 then
        vim.api.nvim_create_autocmd("BufWritePost", {
          pattern = "*/kanata/config.kbd",
          callback = U.debounce_wrap(500, function()
            local check = vim
              .system({
                "kanata",
                "--check",
                "--cfg",
                vim.fn.expand("~/.config/kanata/config.kbd") --[[@as string]],
              }, { text = true })
              :wait()
            if check.code ~= 0 then
              LazyVim.error(
                ("Invalid Kanata config; service not restarted:\n%s\n%s"):format(check.stdout, check.stderr),
                { title = "Kanata" }
              )
              return
            end
            -- Preserve a manually stopped service, e.g. when debugging key mappings.
            local active = vim.system({ "systemctl", "--user", "is-active", "--quiet", "kanata.service" }):wait()
            if active.code ~= 0 then
              return
            end
            local res = vim.system({ "systemctl", "--user", "restart", "kanata.service" }, { text = true }):wait()
            if res.code == 0 then
              LazyVim.info("kanata.service restarted", { title = "Kanata" })
            else
              LazyVim.error(("Failed to restart kanata.service:\n%s"):format(res.stderr), { title = "Kanata" })
            end
          end),
        })
      end

      if vim.g.user_is_asahi and vim.fn.executable("clash-meta") == 1 then
        vim.api.nvim_create_autocmd("BufWritePost", {
          pattern = "*/dot_config/mihomo/encrypted_private_config.yaml.tmpl.age",
          callback = U.debounce_wrap(500, function()
            -- The Fedora unit runs `clash-meta -f /etc/clash-meta/config.yaml -d /var/lib/clash-meta`, and that
            -- `-f` path is a manual `sudo ln -sf ~/.config/mihomo/config.yaml /etc/clash-meta/config.yaml`
            local config = vim
              .system({
                "chezmoi",
                "cat",
                vim.fn.expand("~/.config/mihomo/config.yaml") --[[@as string]],
              }, { text = true })
              :wait()
            if config.code ~= 0 or not config.stdout or config.stdout == "" then
              LazyVim.error("Failed to render the Mihomo config", { title = "Mihomo" })
              return
            end

            local check = vim
              .system({
                "clash-meta",
                "-t",
                "-f",
                "/dev/stdin",
                "-d",
                "/var/lib/clash-meta",
              }, { stdin = config.stdout, text = true })
              :wait()
            if check.code ~= 0 then
              LazyVim.error(("Invalid Mihomo config:\n%s"):format(check.stdout), { title = "Mihomo" })
              return
            end

            local reload = vim
              .system({
                "curl",
                "--noproxy",
                "*",
                "--silent",
                "--show-error",
                "--fail",
                "--max-time",
                "10",
                "--output",
                "/dev/null",
                "--write-out",
                "%{http_code}",
                "-X",
                "PUT",
                "-H",
                "Content-Type: application/json",
                "--data-binary",
                "@-",
                "http://127.0.0.1:9090/configs?force=true",
              }, { stdin = vim.json.encode({ payload = config.stdout }), text = true })
              :wait()
            if reload.code == 0 and reload.stdout == "204" then
              LazyVim.info("Mihomo config reloaded", { title = "Mihomo" })
            else
              LazyVim.error("Failed to reload Mihomo", { title = "Mihomo" })
            end
          end),
        })
      end

      -- -- fix `vim: true` in ~/.aider.conf.yml
      -- vim.api.nvim_create_autocmd("BufReadPre", {
      --   pattern = { ".aider.conf.yml", "dot_aider.conf.yml" },
      --   callback = function(event)
      --     -- vim.opt_local.modelines = 0
      --     vim.bo[event.buf].modeline = false
      --   end,
      -- })
      -- if LazyVim.has("chezmoi.vim") and vim.g["chezmoi#use_tmp_buffer"] == 1 then
      --   vim.g["chezmoi#detect_ignore_pattern"] = "dot_aider.conf.yml"
      -- end

      -- fix `Option 'commentstring' is empty.` sometimes occurs in kitty.conf
      vim.api.nvim_create_autocmd("FileType", {
        pattern = "kitty",
        callback = function()
          vim.opt_local.commentstring = "# %s"
        end,
      })
      -- alternative: remove `auto_reload_config -1` from kitty.conf
      if vim.g.user_is_kitty then
        vim.api.nvim_create_autocmd("BufWritePost", {
          pattern = { "kitty.conf", "kitty.conf.tmpl" },
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

      if vim.fn.executable("rex") == 1 then
        vim.api.nvim_create_autocmd("BufWritePost", {
          pattern = "*/rex/*.lua",
          callback = U.debounce_wrap(500, function()
            local check = vim.system({ "rex", "config", "check", "--json" }, { text = true }):wait()
            local ok, config = pcall(vim.json.decode, check.stdout or "")
            if check.code ~= 0 or not ok or not config.exists or #config.diagnostics > 0 then
              LazyVim.error(
                ("Failed to check Rex config:\n%s\n%s"):format(check.stderr or "", check.stdout or ""),
                { title = "Rex" }
              )
              return
            end

            local res = vim.system({ "rex", "config", "reload" }, { text = true }):wait()
            if res.code == 0 then
              LazyVim.info("Rex config reloaded", { title = "Rex" })
            else
              LazyVim.error(("Failed to reload Rex config:\n%s"):format(res.stderr or ""), { title = "Rex" })
            end
          end),
        })
      end

      if vim.g.user_is_termux then
        vim.api.nvim_create_autocmd("BufWritePost", {
          pattern = { "termux.properties", "private_termux.properties" },
          callback = U.debounce_wrap(500, function()
            local res = vim.system({ "termux-reload-settings" }, { text = true }):wait()
            if res.code == 0 then
              LazyVim.info("Termux settings reloaded", { title = "Termux" })
            else
              LazyVim.error(("Failed to run `termux-reload-settings`:\n%s"):format(res.stderr), { title = "Termux" })
            end
          end),
        })
      end

      if vim.g.user_is_ghostty and vim.g.user_is_macos then
        vim.api.nvim_create_autocmd("BufWritePost", {
          pattern = "*/ghostty/config",
          callback = U.debounce_wrap(500, function()
            local script = [[tell application "Ghostty"
    set term to focused terminal of selected tab of front window
    perform action "reload_config" on term
end tell]]
            local res = vim.system({ "osascript", "-e", script }, { text = true }):wait()
            if res.code == 0 then
              LazyVim.info("Ghostty config reloaded", { title = "Ghostty" })
            else
              LazyVim.error(("Failed to reload Ghostty config:\n%s"):format(res.stderr), { title = "Ghostty" })
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
        pattern = {
          [".*/vscode/settings%.json"] = "jsonc",
          [".*/vscode/keybindings%.json"] = "jsonc",
          [".*%.pi/agent/models%.json"] = "jsonc",
          [".*private_dot_pi/private_agent/models%.json"] = "jsonc",
          [".*%.pi/agent/extensions/sandbox%.json"] = "jsonc",
          [".*private_dot_pi/private_agent/extensions/sandbox%.json"] = "jsonc",
          [".*%.pi/sandbox%.json"] = "jsonc",
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

  -- Kanata
  {
    "nvim-treesitter/nvim-treesitter",
    opts = function()
      vim.filetype.add({ pattern = { [".*/kanata/.+%.kbd"] = "kanata" } })

      vim.api.nvim_create_autocmd("User", {
        pattern = "TSUpdate",
        callback = function()
          ---@diagnostic disable-next-line: inject-field
          require("nvim-treesitter.parsers").kanata = {
            install_info = {
              url = "https://github.com/postsolar/tree-sitter-kanata",
              revision = "af53b4c35d6faa3b4ba7c317fb795a6eb679b42a",
            },
          }
        end,
      })
    end,
  },
  {
    "nvim-treesitter/nvim-treesitter",
    opts = { ensure_installed = { "kanata" } },
  },
}
