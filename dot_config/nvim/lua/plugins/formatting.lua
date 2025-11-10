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
      if not LazyVim.has_extra("formatting.biome") then
        return
      end

      opts.formatters = opts.formatters or {}
      -- opts.formatters.biome = opts.formatters.biome or {}
      -- opts.formatters.biome.require_cwd = nil -- make biome config file optional

      opts.formatters["biome-check"] = {
        args = function(self, ctx)
          local args = require("conform.formatters.biome-check").args
          if not args then
            return {}
          end
          if type(args) == "function" then
            return args(self, ctx)
          end

          -- ref: https://github.com/stevearc/conform.nvim/blob/016bc8174a675e1dbf884b06a165cd0c6c03f9af/lua/conform/formatters/biome.lua#L10-L24
          if self:cwd(ctx) then
            return args
          end
          -- only when biome.json{,c} don't exist
          return vim.list_extend(type(args) == "table" and vim.deepcopy(args) or { args }, {
            "--indent-style",
            vim.bo[ctx.buf].expandtab and "space" or "tab",
            "--indent-width",
            ctx.shiftwidth,
          })
        end,
      }

      -- (except vue) remove prettier if biome is present, and use biome-check instead of biome
      local by_ft = opts.formatters_by_ft or {}
      for ft in pairs(by_ft) do
        if
          not (type(by_ft[ft]) == "function")
          ---@cast by_ft table<string, conform.FiletypeFormatterInternal>
          and vim.list_contains(by_ft[ft], "biome")
        then
          for i = #by_ft[ft], 1, -1 do
            if (by_ft[ft][i] == "prettier" and ft ~= "vue") or by_ft[ft][i] == "biome" then
              table.remove(by_ft[ft], i)
            end
          end
          if ft == "vue" then
            table.insert(by_ft[ft], 1, "biome-organize-imports")
          else
            table.insert(by_ft[ft], "biome-check")
          end
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
          "dbout", -- vim-dadbod
        },
        callback = function(ev)
          vim.b[ev.buf].minitrailspace_disable = true
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
