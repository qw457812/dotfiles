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
      opts.formatters["biome-check"] = opts.formatters["biome-check"] or {}
      opts.formatters["biome-check"].require_cwd = nil -- make biome config file optional

      ---@param self conform.JobFormatterConfig
      ---@param ctx conform.Context
      ---@return string|string[]
      opts.formatters["biome-check"].args = function(self, ctx)
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
      end

      -- remove prettier if biome-check is present (except vue)
      for ft, formatters in pairs(opts.formatters_by_ft or {}) do
        if
          not (type(formatters) == "function")
          ---@cast formatters conform.FiletypeFormatterInternal
          and vim.list_contains(formatters, "biome-check")
          and vim.list_contains(formatters, "prettier")
        then
          if ft == "vue" then
            for i = #formatters, 1, -1 do
              if formatters[i] == "biome-check" then
                table.remove(formatters, i)
              end
            end
            table.insert(formatters, 1, "biome-organize-imports")
          else
            for i = #formatters, 1, -1 do
              if formatters[i] == "prettier" then
                table.remove(formatters, i)
              end
            end
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
          "log",
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
