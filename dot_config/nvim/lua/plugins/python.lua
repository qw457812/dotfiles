if not LazyVim.has_extra("lang.python") then
  return {}
end

return {
  -- note that LazyVim use the new "regexp" branch: https://github.com/linux-cultist/venv-selector.nvim/tree/regexp
  {
    "linux-cultist/venv-selector.nvim",
    optional = true,
    -- TODO: temporary fix: venv-selector does not work with extras.editor.fzf
    -- - https://github.com/LazyVim/LazyVim/issues/3612
    -- - https://github.com/linux-cultist/venv-selector.nvim/issues/142
    dependencies = { "nvim-telescope/telescope.nvim" },
    opts = {
      settings = {
        options = {
          on_telescope_result_callback = function(filename)
            return require("util.path").replace_home_with_tilde(filename):gsub("/bin/python", "")
          end,
        },
      },
    },
  },

  -- isort
  {
    "williamboman/mason.nvim",
    opts = {
      ensure_installed = {
        "isort",
        "debugpy", -- required by nvim-dap-python
      },
    },
  },
  {
    "nvimtools/none-ls.nvim",
    optional = true,
    opts = function(_, opts)
      local nls = require("null-ls")
      opts.sources = opts.sources or {}
      table.insert(opts.sources, nls.builtins.formatting.isort)
    end,
  },
  {
    "stevearc/conform.nvim",
    optional = true,
    opts = function(_, opts)
      if LazyVim.has_extra("formatting.black") then
        opts.formatters_by_ft = opts.formatters_by_ft or {}
        -- run multiple formatters sequentially
        -- TODO: ruff_format, ruff_organize_imports, ruff_fix?
        -- https://github.com/stevearc/conform.nvim#options
        -- https://github.com/fredrikaverpil/dotfiles/blob/be037d3e442b25d356f0bdd18ac2a17c346d71aa/nvim-fredrik/lua/lang/python.lua#L156
        opts.formatters_by_ft.python = { "isort", "black" }
      end
    end,
  },

  -- TODO: get the debugpy path from $VIRTUAL_ENV, then fallback to mason?
  -- https://github.com/fredrikaverpil/dotfiles/blob/be037d3e442b25d356f0bdd18ac2a17c346d71aa/nvim-fredrik/lua/lang/python.lua#L32
  -- https://github.com/LazyVim/LazyVim/pull/1031#discussion_r1251566896

  -- TODO: mfussenegger/nvim-lint: mypy?
  -- https://github.com/akthe-at/.dotfiles/blob/49beab5ec32659fba8f3b0c5ca3a6f75cc7a7d8a/nvim/lua/plugins/lint.lua
  -- https://github.com/fredrikaverpil/dotfiles/blob/be037d3e442b25d356f0bdd18ac2a17c346d71aa/nvim-fredrik/lua/lang/python.lua#L177
}
