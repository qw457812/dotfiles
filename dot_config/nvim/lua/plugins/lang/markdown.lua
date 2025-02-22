if not LazyVim.has_extra("lang.markdown") then
  return {}
end

local use_image_nvim = false -- use image.nvim instead of snacks image
local image_cursor_only = false

return {
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
    ft = U.markdown.render_markdown_ft("gitcommit"),
    opts = {
      -- win_options = {
      --   -- toggling this plugin should also toggle conceallevel
      --   conceallevel = { default = 0 },
      -- },
      heading = {
        icons = function(ctx)
          return ("%s%s "):format(table.concat(ctx.sections, "."), #ctx.sections > 1 and "" or ".")
        end,
      },
      code = {
        -- https://github.com/MeanderingProgrammer/render-markdown.nvim/issues/246#issuecomment-2510220411
        disable_background = vim.g.user_transparent_background,
        border = vim.g.user_transparent_background and "none" or nil,
        inline_pad = 1,
      },
    },
  },
  {
    "nvim-cmp",
    optional = true,
    opts = function(_, opts)
      table.insert(opts.sources, { name = "render-markdown" })
    end,
  },
  {
    "saghen/blink.cmp",
    optional = true,
    opts = {
      sources = {
        default = { "markdown" },
        providers = {
          markdown = {
            name = "RenderMarkdown",
            module = "render-markdown.integ.blink",
          },
        },
      },
    },
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
