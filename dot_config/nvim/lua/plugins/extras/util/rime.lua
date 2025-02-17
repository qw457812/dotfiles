if not U.rime_ls.cond() then
  return {}
end

-- https://github.com/wlh320/rime-ls/blob/4986d4d765870846f689e1e06dc9baa2ac2aff34/doc/nvim-with-blink.md
-- https://github.com/Kaiser-Yang/dotfiles/tree/bdda941b06cce5c7505bc725f09dd3fa17763730
-- https://github.com/wlh320/wlh-dotfiles/blob/85d41a30588642617177374b4cea2ec96c1b2740/config/nvim/lua/rime.lua
-- https://github.com/liubianshi/cmp-lsp-rimels/tree/blink.cmp
return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        rime_ls = {
          init_options = {
            enabled = vim.g.rime_enabled == true,
            shared_data_dir = "/Library/Input Methods/Squirrel.app/Contents/SharedSupport",
            user_data_dir = vim.fn.expand("~/.local/share/rime-ls"), -- https://github.com/zhhmn/huma-rime
            log_dir = vim.fn.expand("~/.local/share/rime-ls"),
            max_tokens = 4,
            always_incomplete = true,
            long_filter_text = true,
          },
          on_attach = U.rime_ls.on_attach,
          handlers = {
            -- https://github.com/liubianshi/.nvim/blob/6fb24895acc36e4b0a2576af6683caf8c852d2bd/Plugins/nvim-lspconfig.lua#L117
            ["window/showMessage"] = function(err, res, ctx)
              if
                res.type == vim.lsp.protocol.MessageType.Info and res.message == "Use an initialized rime instance."
              then
                return
              end
              vim.lsp.handlers["window/showMessage"](err, res, ctx)
            end,
          },
        },
      },
      setup = {
        rime_ls = U.rime_ls.setup,
      },
    },
  },

  {
    "saghen/blink.cmp",
    optional = true,
    ---@module 'blink.cmp'
    ---@type blink.cmp.Config
    opts = {
      -- completion = {
      --   accept = {
      --     create_undo_point = false,
      --   },
      -- },
      keymap = {
        ["<space>"] = U.rime_ls.cmp.accept_n(1),
        -- TODO: not working when mapping `:<space>` to `：` (Chinese punctuation)
        [":"] = U.rime_ls.cmp.accept_n(2),
        ["'"] = U.rime_ls.cmp.accept_n(3),
        ["<esc>"] = U.rime_ls.cmp.esc_clear(),
        ["<cr>"] = U.rime_ls.cmp.enter_commit_code(),
      },
      sources = {
        providers = {
          lsp = {
            -- copied from: https://github.com/saghen/blink.cmp/blob/035e1bae395b2b34c6cf0234f4270bf9481905b4/lua/blink/cmp/config/sources.lua#L56-L62
            transform_items = function(_, items)
              -- filter out text items, since we have the buffer source
              ---@param item blink.cmp.CompletionItem
              return vim.tbl_filter(function(item)
                return item.kind ~= require("blink.cmp.types").CompletionItemKind.Text or U.rime_ls.cmp.is_rime(item)
              end, items)
            end,
          },
        },
      },
    },
  },

  {
    "nvim-lualine/lualine.nvim",
    optional = true,
    opts = function(_, opts)
      table.insert(opts.sections.lualine_x, 2, {
        function()
          return "ㄓ"
        end,
        cond = function()
          return vim.g.rime_enabled
        end,
        color = function()
          return { fg = Snacks.util.color("MiniIconsRed") }
        end,
      })
    end,
  },

  {
    "Wansmer/symbol-usage.nvim",
    optional = true,
    opts = function(_, opts)
      LazyVim.extend(opts, "disable.lsp", { "rime_ls" })
    end,
  },

  {
    "kosayoda/nvim-lightbulb",
    optional = true,
    opts = function(_, opts)
      LazyVim.extend(opts, "ignore.clients", { "rime_ls" })
    end,
  },
}
