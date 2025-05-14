local base46_did_reload = false
---@param force? boolean default false
local function reload_base46(force)
  if base46_did_reload and force ~= true then
    return
  end
  require("base46").load_all_highlights()
  base46_did_reload = true
end

-- copied from: https://github.com/AstroNvim/astrocommunity/blob/e56d7b3c52cb496780a901123705d7824914642b/lua/astrocommunity/pack/nvchad-ui/init.lua
return {
  "NvChad/ui",
  lazy = false,
  keys = function(_, keys)
    -- theme
    vim.list_extend(keys, {
      {
        "<Leader>uC",
        function()
          require("nvchad.themes").open()
          base46_did_reload = true
        end,
        desc = "Themes (NvChad)",
      },
    })
    -- tabufline
    if not LazyVim.has("bufferline.nvim") then
      -- stylua: ignore
      vim.list_extend(keys, {
        { "[b", function() require("nvchad.tabufline").prev() end, desc = "Prev Buffer" },
        { "]b", function() require("nvchad.tabufline").next() end, desc = "Next Buffer" },
        { "[B", function() require("nvchad.tabufline").move_buf(-1) end, desc = "Move buffer prev" },
        { "]B", function() require("nvchad.tabufline").move_buf(1) end, desc = "Move buffer next" },
        { "<Down>", function() require("nvchad.tabufline").next() end, desc = "Next Buffer" },
        { "<Up>", function() require("nvchad.tabufline").prev() end, desc = "Prev Buffer" },
        { "J", function() require("nvchad.tabufline").next() end, desc = "Next Buffer" },
        { "K", function() require("nvchad.tabufline").prev() end, desc = "Prev Buffer" },
        { "<leader>bH", function() vim.api.nvim_set_current_buf(vim.t.bufs[1]) end, desc = "Goto First Buffer" }, -- <cmd>brewind<cr>
        { "<leader>bL", function() vim.api.nvim_set_current_buf(vim.t.bufs[#vim.t.bufs]) end, desc = "Goto Last Buffer" }, -- <cmd>blast<cr>
        { "<leader>bh", function() require("nvchad.tabufline").closeBufs_at_direction("left") end, desc = "Delete Buffers to the Left" },
        { "<leader>bl", function() require("nvchad.tabufline").closeBufs_at_direction("right") end, desc = "Delete Buffers to the Right" },
      })
      -- unlike bufferline.nvim, this is not the visible position
      for i = 1, 9 do
        table.insert(keys, {
          "<leader>" .. i,
          function()
            local bufs = vim.t.bufs
            vim.api.nvim_set_current_buf(bufs[i] or bufs[#bufs])
          end,
          desc = "which_key_ignore",
        })
      end
    end
  end,
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
          modules = {
            -- copied from: https://github.com/NvChad/ui/blob/4466c87073c811c22b14215ba8a0cfc7d1b8b688/lua/nvchad/tabufline/modules.lua#L59-L62
            treeOffset = function()
              local function getNeoTreeWidth()
                for _, win in pairs(vim.api.nvim_tabpage_list_wins(0)) do
                  if vim.bo[vim.api.nvim_win_get_buf(win)].ft == "neo-tree" then
                    return vim.api.nvim_win_get_width(win)
                  end
                end
                return 0
              end
              local w = getNeoTreeWidth()
              return (w == 0 and "" or "%#NvimTreeNormal#" .. string.rep(" ", w) .. "%#NvimTreeWinSeparator#" .. "│")
                .. " "
            end,
          },
        },
      },
      nvdash = {
        load_on_startup = not Snacks.config.dashboard.enabled,
        -- TODO: buttons
      },
      lsp = { signature = false },
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
        local LazyUtil = require("lazy.util")

        vim.api.nvim_create_autocmd("User", {
          pattern = "LazyVimKeymaps",
          once = true,
          callback = function()
            vim.keymap.set("n", "<leader>ur", function()
              require("base46").toggle_theme()
              base46_did_reload = true
            end, { desc = "Toggle Theme (NvChad)" })
          end,
        })

        -- reload base46 on vim.g.user_transparent_background change (kitty/neovide)
        U.on_very_very_lazy(function()
          local cache_file = vim.fn.stdpath("cache") .. "/user_transparent_background.txt"
          local prev_transparent = vim.fn.filereadable(cache_file) == 1 and LazyUtil.read_file(cache_file) or nil
          local transparent = tostring(vim.g.user_transparent_background)
          LazyUtil.write_file(cache_file, transparent)
          if prev_transparent ~= transparent then
            reload_base46()
          end
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
        reload_base46(true)
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
        -- for opts.ui.tabufline.modules.treeOffset
        {
          "nvim-neo-tree/neo-tree.nvim",
          optional = true,
          opts = function()
            pcall(function()
              dofile(vim.g.base46_cache .. "nvimtree")
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
            LazyVim.on_load("diffview.nvim", reload_base46)
          end,
        },
      },
    },
  },
}
