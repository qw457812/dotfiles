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
          -- do not use home dir as root dir
          root_dir = function(bufnr, on_dir)
            local util = require("lspconfig.util")
            local fname = vim.api.nvim_buf_get_name(bufnr)
            -- see:
            -- - https://github.com/neovim/nvim-lspconfig/blob/d9879110d0422a566fa01d732556f4d5515e1738/lua/lspconfig/configs/lua_ls.lua#L18
            -- - https://github.com/neovim/nvim-lspconfig/blob/5a49a97f9d3de5c39a2b18d583035285b3640cb0/lsp/lua_ls.lua#L75-L84
            local root = util.root_pattern(vim.lsp.config.lua_ls.root_markers)(fname)
            -- ref: https://github.com/neovim/nvim-lspconfig/blob/7c284f44fe7b120cf1e5b63d2b0648c3831c4048/lua/lspconfig/configs/lua_ls.lua#L17-L28
            on_dir(root ~= vim.env.HOME and root or util.root_pattern("lua/")(fname))
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
      ensure_installed = {
        "selene",
        "luacheck",
      },
    },
  },
}
