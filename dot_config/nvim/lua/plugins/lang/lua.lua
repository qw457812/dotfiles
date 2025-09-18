---@type LazySpec
return {
  {
    "neovim/nvim-lspconfig",
    ---@type PluginLspOpts
    opts = {
      ---@type table<string, vim.lsp.Config>
      servers = {
        lua_ls = {
          mason = not vim.g.user_is_termux and nil, -- run `pkg install lua-language-server` on termux
          -- prefer parent of lua/ over home as root (home has stylua.toml)
          root_dir = function(bufnr, on_dir)
            -- ref: https://github.com/neovim/nvim-lspconfig/blob/7c284f44fe7b120cf1e5b63d2b0648c3831c4048/lua/lspconfig/configs/lua_ls.lua#L17-L28
            local root = vim.fs.root(bufnr, vim.lsp.config.lua_ls.root_markers)
            on_dir(root ~= vim.env.HOME and root or vim.fs.root(bufnr, "lua"))
          end,
          -- https://luals.github.io/wiki/settings/
          -- https://github.com/LuaLS/lua-language-server/blob/12013babf4e386bdde1b21af57a2a06b6e127703/locale/zh-cn/setting.lua
          settings = {
            Lua = {
              -- hover = { expandAlias = false },
              type = {
                castNumberToInteger = true,
                inferParamType = true,
              },
              -- diagnostics = {
              --   disable = { "incomplete-signature-doc", "trailing-space" },
              --   groupSeverity = {
              --     strong = "Warning",
              --     strict = "Warning",
              --   },
              --   groupFileStatus = {
              --     ["ambiguity"] = "Opened",
              --     ["await"] = "Opened",
              --     ["codestyle"] = "None",
              --     ["duplicate"] = "Opened",
              --     ["global"] = "Opened",
              --     ["luadoc"] = "Opened",
              --     ["redefined"] = "Opened",
              --     ["strict"] = "Opened",
              --     ["strong"] = "Opened",
              --     ["type-check"] = "Opened",
              --     ["unbalanced"] = "Opened",
              --     ["unused"] = "Opened",
              --   },
              --   unusedLocalExclude = { "_*" },
              -- },
            },
          },
        },
      },
    },
  },

  -- https://github.com/folke/dot/blob/13b8ed8d40755b58163ffff30e6a000d06fc0be0/nvim/lua/plugins/lsp.lua#L79
  {
    "mfussenegger/nvim-lint",
    opts = {
      linters_by_ft = {
        lua = { "selene", "luacheck" },
      },
      linters = {
        selene = {
          -- `condition` is a LazyVim extension that allows you to dynamically enable/disable linters based on the context
          condition = function(ctx)
            if vim.g.user_is_termux then
              return false
            end
            local root = LazyVim.root.get({ normalize = true })
            if root ~= vim.uv.cwd() then
              return false
            end
            return vim.fs.find({ "selene.toml" }, { path = root, upward = true })[1]
          end,
        },
        luacheck = {
          condition = function(ctx)
            local root = LazyVim.root.get({ normalize = true })
            if root ~= vim.uv.cwd() then
              return false
            end
            return vim.fs.find({ ".luacheckrc" }, { path = root, upward = true })[1]
          end,
        },
      },
    },
  },

  {
    "mason-org/mason.nvim",
    opts = {
      ensure_installed = vim.list_extend({ "luacheck" }, vim.g.user_is_termux and {} or { "selene" }),
    },
  },
  {
    "mason-org/mason.nvim",
    opts = function(_, opts)
      -- run `pkg install stylua` on termux
      if vim.g.user_is_termux then
        for i, pkg in ipairs(opts.ensure_installed) do
          if pkg == "stylua" then
            table.remove(opts.ensure_installed, i)
            break
          end
        end
      end
    end,
  },
}
