-- copied from: https://github.com/AstroNvim/astrocommunity/blob/e56d7b3c52cb496780a901123705d7824914642b/lua/astrocommunity/pack/nvchad-ui/init.lua
return {
  "NvChad/ui",
  lazy = false,
  keys = {
    -- stylua: ignore
    { "<Leader>uC", function() require("nvchad.themes").open() end, desc = "Themes (NvChad)" },
  },
  opts = function()
    return {
      base46 = {
        theme = "onedark",
        hl_add = {
          SnacksIndent = { fg = "line" },
          SnacksIndentScope = { fg = "light_grey" },
          BufferLineSeparator = { fg = "black2", bg = "black2" },
          BufferLineSeparatorVisible = { fg = "black2", bg = "black2" },
          BufferLineSeparatorSelected = { fg = "black2", bg = "black2" },
        },
        hl_override = {
          FloatTitle = { fg = "white", bg = "NONE" },
        },
        transparency = vim.g.user_transparent_background,
        -- penumbra_dark, github_dark, oceanic-next
        theme_toggle = { "onedark", "bearded-arc" },
        -- https://github.com/NvChad/base46/blob/3fa132de83788b34db0bb170c2a4e9138ccad3e7/lua/base46/init.lua#L6-L23
        integrations = { "diffview" },
      },
      ui = {
        statusline = {
          enabled = not LazyVim.has("lualine.nvim"),
        },
        tabufline = {
          enabled = not LazyVim.has("bufferline.nvim"),
        },
      },
      nvdash = {
        load_on_startup = not Snacks.config.dashboard.enabled,
        -- TODO: buttons
      },
    }
  end,
  init = function()
    -- load the lazy opts on module load
    package.preload["chadrc"] = function()
      local plugin = require("lazy.core.config").spec.plugins["ui"]
      return require("lazy.core.plugin").values(plugin, "opts", false)
    end
  end,
  config = function()
    pcall(function()
      dofile(vim.g.base46_cache .. "defaults")
      dofile(vim.g.base46_cache .. "statusline")
    end)
    require("nvchad")
  end,
  specs = {
    {
      "LazyVim/LazyVim",
      opts = function()
        vim.api.nvim_create_autocmd("User", {
          pattern = "LazyVimKeymaps",
          once = true,
          callback = function()
            vim.keymap.set("n", "<leader>ur", function()
              require("base46").toggle_theme()
            end, { desc = "Toggle Theme (NvChad)" })
          end,
        })

        -- HACK: different vim.g.user_transparent_background between kitty and neovide
        U.on_very_very_lazy(function()
          require("base46").load_all_highlights()
        end)
      end,
      -- config = function(_, opts)
      --   opts.colorscheme = function() end
      --   require("lazyvim").setup(opts)
      -- end,
    },
    {
      "hrsh7th/nvim-cmp",
      optional = true,
      opts = function(_, opts)
        return vim.tbl_deep_extend("force", opts, require("nvchad.cmp"))
      end,
    },
    {
      "saghen/blink.cmp",
      optional = true,
      opts = function(_, opts)
        -- https://github.com/NvChad/NvChad/discussions/3244
        -- https://github.com/NvChad/ui/blob/9a60cd12635c7235200d810bf94019c0c931a656/lua/nvchad/blink/config.lua
        return vim.tbl_deep_extend("force", opts, {
          completion = {
            menu = {
              draw = {
                components = require("nvchad.blink").components,
              },
            },
          },
        })
      end,
    },
    -- Disable unnecessary plugins
    -- { "akinsho/bufferline.nvim", optional = true, cond = false },
    -- { "nvim-lualine/lualine.nvim", optional = true, cond = false },
    -- {
    --   "folke/snacks.nvim",
    --   optional = true,
    --   opts = { dashboard = { enabled = false } },
    -- },
    { "echasnovski/mini.hipatterns", optional = true, cond = false },
    -- add lazy loaded dependencies
    { "NvChad/volt", lazy = true },
    {
      "NvChad/base46",
      lazy = true,
      init = function()
        vim.g.base46_cache = vim.fn.stdpath("data") .. "/base46_cache/"
      end,
      build = function()
        vim.g.base46_cache = vim.fn.stdpath("data") .. "/base46_cache/"
        require("base46").load_all_highlights()
      end,
      -- load base46 cache when necessary
      specs = {
        {
          "nvim-treesitter/nvim-treesitter",
          optional = true,
          opts = function()
            pcall(function()
              dofile(vim.g.base46_cache .. "syntax")
              dofile(vim.g.base46_cache .. "treesitter")
            end)
          end,
        },
        {
          "folke/which-key.nvim",
          optional = true,
          opts = function()
            pcall(function()
              dofile(vim.g.base46_cache .. "whichkey")
            end)
          end,
        },
        {
          "lukas-reineke/indent-blankline.nvim",
          optional = true,
          opts = function()
            pcall(function()
              dofile(vim.g.base46_cache .. "blankline")
            end)
          end,
        },
        {
          "nvim-telescope/telescope.nvim",
          optional = true,
          opts = function()
            pcall(function()
              dofile(vim.g.base46_cache .. "telescope")
            end)
          end,
        },
        {
          "neovim/nvim-lspconfig",
          optional = true,
          opts = function()
            pcall(function()
              dofile(vim.g.base46_cache .. "lsp")
            end)
          end,
        },
        {
          "nvim-tree/nvim-tree.lua",
          optional = true,
          opts = function()
            pcall(function()
              dofile(vim.g.base46_cache .. "nvimtree")
            end)
          end,
        },
        {
          "williamboman/mason.nvim",
          optional = true,
          opts = function()
            pcall(function()
              dofile(vim.g.base46_cache .. "mason")
            end)
          end,
        },
        {
          "lewis6991/gitsigns.nvim",
          optional = true,
          opts = function()
            pcall(function()
              dofile(vim.g.base46_cache .. "git")
            end)
          end,
        },
        {
          "nvim-tree/nvim-web-devicons",
          optional = true,
          opts = function()
            pcall(function()
              dofile(vim.g.base46_cache .. "devicons")
            end)
          end,
        },
        {
          "echasnovski/mini.icons",
          optional = true,
          opts = function()
            pcall(function()
              dofile(vim.g.base46_cache .. "devicons")
            end)
          end,
        },
        {
          "hrsh7th/nvim-cmp",
          optional = true,
          opts = function()
            pcall(function()
              dofile(vim.g.base46_cache .. "cmp")
            end)
          end,
        },
        {
          "saghen/blink.cmp",
          optional = true,
          opts = function()
            pcall(function()
              dofile(vim.g.base46_cache .. "blink")
            end)
          end,
        },
        -- opts.base46.integrations
        {
          "sindrets/diffview.nvim",
          optional = true,
          opts = function()
            pcall(function()
              dofile(vim.g.base46_cache .. "diffview")
            end)
          end,
        },
      },
    },
  },
}
