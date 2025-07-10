if not LazyVim.has_extra("lang.markdown") then
  return {}
end

local use_image_nvim = false -- use image.nvim instead of snacks image
local image_cursor_only = false

return {
  {
    "LazyVim/LazyVim",
    opts = function()
      if vim.fn.has("nvim-0.11") == 1 then
        vim.api.nvim_create_autocmd("FileType", {
          pattern = "markdown",
          callback = function(ev)
            local buf = ev.buf
            vim.defer_fn(function()
              if not vim.api.nvim_buf_is_valid(buf) then
                return
              end

              -- see: https://github.com/neovim/neovim/blob/eefd72fff753e923abf88ac85b1de0859cf24635/runtime/ftplugin/markdown.lua
              pcall(vim.keymap.del, "n", "gO", { buffer = buf })
              -- see: https://github.com/LazyVim/LazyVim/blob/0b6d1c00506a6ea6af51646e6ec7212ac89f86e5/lua/lazyvim/plugins/extras/editor/illuminate.lua#L45-L52
              vim.keymap.set("n", "]]", function()
                require("vim.treesitter._headings").jump({ count = 1 })
              end, { buffer = buf, silent = false, desc = "Jump to next section" })
              vim.keymap.set("n", "[[", function()
                require("vim.treesitter._headings").jump({ count = -1 })
              end, { buffer = buf, silent = false, desc = "Jump to previous section" })
            end, 100)
          end,
        })
      end
    end,
  },

  {
    "neovim/nvim-lspconfig",
    opts = function(_, opts)
      if vim.g.user_is_termux then
        opts.servers.marksman = nil
      end
    end,
  },

  -- https://github.com/MeanderingProgrammer/dotfiles/blob/845016440183396f4f6d524cdd001828dbbdecba/.config/nvim/lua/mp/plugins/lang/markdown.lua#L47
  {
    "MeanderingProgrammer/render-markdown.nvim",
    optional = true,
    ft = "gitcommit",
    opts = {
      -- heading = {
      --   icons = function(ctx)
      --     return ("%s%s "):format(table.concat(ctx.sections, "."), #ctx.sections > 1 and "" or ".")
      --   end,
      -- },
      code = vim.tbl_deep_extend(
        "force",
        {
          inline_pad = 1,
        },
        -- https://github.com/MeanderingProgrammer/render-markdown.nvim/issues/246#issuecomment-2510220411
        vim.g.user_transparent_background
            and {
              disable_background = true,
              border = "none",
              language_border = " ",
              highlight_border = false,
            }
          or {}
      ),
      -- checkbox = {
      --   enabled = true,
      -- },
      completions = {
        -- blink = { enabled = true },
        lsp = { enabled = true },
        filter = {
          callout = function(value)
            return value.category ~= "obsidian"
          end,
        },
      },
    },
  },

  {
    "L3MON4D3/LuaSnip",
    optional = true,
    opts = function()
      -- https://github.com/MeanderingProgrammer/render-markdown.nvim/issues/141
      require("luasnip").filetype_extend("gitcommit", { "markdown" })
    end,
  },

  {
    "wurli/contextindent.nvim",
    enabled = false, -- wrong indent on `o` in nested list
    dependencies = {
      {
        "nvim-treesitter/nvim-treesitter",
        opts = {
          indent = {
            disable = function(lang, buf)
              return lang == "markdown" or vim.bo[buf].filetype == "markdown"
            end,
          },
        },
      },
    },
    ft = "markdown",
    opts = { pattern = "*.md" },
  },

  {
    "gaoDean/autolist.nvim",
    enabled = false, -- imap conflicts with blink.cmp
    ft = "markdown",
    -- stylua: ignore
    keys = {
      { "<tab>",   "<cmd>AutolistTab<cr>",                ft = "markdown", mode = "i" },
      { "<s-tab>", "<cmd>AutolistShiftTab<cr>",           ft = "markdown", mode = "i" },
      { "<CR>",    "<CR><cmd>AutolistNewBullet<cr>",      ft = "markdown", mode = "i" },
      { "o",       "o<cmd>AutolistNewBullet<cr>",         ft = "markdown" },
      { "O",       "O<cmd>AutolistNewBulletBefore<cr>",   ft = "markdown" },
      { "<CR>",    "<cmd>AutolistToggleCheckbox<cr><CR>", ft = "markdown" },
      { "<M-r>",   "<cmd>AutolistRecalculate<cr>",        ft = "markdown" },
      { ">>",      ">><cmd>AutolistRecalculate<cr>",      ft = "markdown" },
      { "<<",      "<<<cmd>AutolistRecalculate<cr>",      ft = "markdown" },
      { "dd",      "dd<cmd>AutolistRecalculate<cr>",      ft = "markdown" },
      { "d",       "d<cmd>AutolistRecalculate<cr>",       ft = "markdown", mode = "v" },
    },
    opts = {},
    config = function(_, opts)
      require("autolist").setup(opts)

      vim.api.nvim_create_autocmd("FileType", {
        pattern = "markdown",
        callback = function(event)
          -- cycle list types with dot-repeat
          vim.keymap.set(
            "n",
            "].",
            require("autolist").cycle_next_dr,
            { expr = true, buffer = event.buf, desc = "Next List Type" }
          )
          vim.keymap.set(
            "n",
            "[.",
            require("autolist").cycle_prev_dr,
            { expr = true, buffer = event.buf, desc = "Prev List Type" }
          )
        end,
      })
    end,
  },

  {
    "3rd/image.nvim",
    optional = true,
    ft = function(_, ft)
      if use_image_nvim then
        vim.list_extend(ft, { "markdown" })
      end
    end,
    opts = {
      integrations = {
        markdown = {
          enabled = use_image_nvim,
          only_render_image_at_cursor = image_cursor_only,
          clear_in_insert_mode = true,
          -- download_remote_images = false,
        },
      },
    },
  },

  {
    "3rd/diagram.nvim",
    enabled = false, -- bad performance
    cond = function()
      return use_image_nvim and not image_cursor_only and LazyVim.has("image.nvim") and vim.fn.executable("mmdc") == 1
    end,
    dependencies = { "3rd/image.nvim" },
    ft = "markdown",
    opts = {
      renderer_options = {
        mermaid = {
          background = vim.g.user_transparent_background and "transparent" or nil,
          theme = "dark",
          -- scale = 2,
        },
      },
    },
  },

  {
    "kosayoda/nvim-lightbulb",
    optional = true,
    opts = function(_, opts)
      LazyVim.extend(opts, "ignore.clients", { "marksman" })
    end,
  },
}
