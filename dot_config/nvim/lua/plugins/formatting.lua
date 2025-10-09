---@type LazySpec
return {
  -- {
  --   "stevearc/conform.nvim",
  --   optional = true,
  --   ---@module "conform"
  --   ---@type conform.setupOpts
  --   opts = {
  --     default_format_opts = {
  --       timeout_ms = 30000, -- sqlfluff
  --     },
  --   },
  -- },

  -- biome
  {
    "stevearc/conform.nvim",
    optional = true,
    ---@module "conform"
    ---@param opts conform.setupOpts
    opts = function(_, opts)
      if not (LazyVim.has_extra("formatting.biome") and LazyVim.has_extra("formatting.prettier")) then
        return
      end

      -- remove "prettier" if "biome" is present
      for ft in pairs(opts.formatters_by_ft or {}) do
        if
          vim.islist(opts.formatters_by_ft[ft])
          and vim.list_contains(opts.formatters_by_ft[ft] --[[@as string[] ]], "biome")
        then
          opts.formatters_by_ft[ft] = vim.tbl_filter(function(formatter)
            return formatter ~= "prettier"
          end, opts.formatters_by_ft[ft] --[[@as string[] ]])
        end
      end
    end,
  },

  {
    "nvim-mini/mini.align",
    vscode = true,
    keys = {
      -- { "ga", mode = { "n", "x" }, desc = "Align" },
      {
        "gA",
        mode = {
          -- "n",
          "x",
        },
        desc = "Align with Preview",
      },
    },
    opts = {
      mappings = {
        start = "", -- disabled since text-case.nvim or coerce.nvim uses `ga`
        start_with_preview = "gA",
      },
    },
    config = function(_, opts)
      local orig_gA_keymap = vim.fn.maparg("gA", "n", false, true) --[[@as table<string,any>]]
      require("mini.align").setup(opts)
      if not vim.tbl_isempty(orig_gA_keymap) then
        vim.fn.mapset("n", false, orig_gA_keymap) -- orgmode uses `gA`
      end
    end,
  },

  {
    "nvim-mini/mini.trailspace",
    event = { "BufReadPost", "BufNewFile" },
    keys = {
      { "<leader>cw", "<cmd>lua MiniTrailspace.trim()<CR>", desc = "Erase Whitespace" },
    },
    opts = function()
      vim.api.nvim_create_autocmd("FileType", {
        pattern = {
          "gitcommit", -- git commit --verbose
        },
        callback = function(event)
          vim.b[event.buf].minitrailspace_disable = true
        end,
      })

      Snacks.toggle({
        name = "Mini Trailspace",
        get = function()
          return not vim.g.minitrailspace_disable
        end,
        set = function(state)
          vim.g.minitrailspace_disable = not state
          if package.loaded["mini.trailspace"] then
            if state then
              require("mini.trailspace").highlight()
            else
              require("mini.trailspace").unhighlight()
            end
          end
        end,
      }):map("<leader>u<space>")
    end,
  },
}
