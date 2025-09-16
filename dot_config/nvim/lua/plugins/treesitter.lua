---@type LazySpec
return {
  {
    "nvim-treesitter/nvim-treesitter",
    keys = {
      { "<c-space>", false },
      { "<bs>", false, mode = "x" },
    },
    ---@param opts TSConfig
    opts = function(_, opts)
      local TS = require("nvim-treesitter")

      -- Unset unused old treesitter config
      opts.incremental_selection = nil
      opts.textobjects = nil

      -- Setup highlight and indent on our own
      opts.highlight = nil
      opts.indent = nil
      local installed =
        LazyVim.dedup(vim.list_extend(TS.get_installed("parsers"), opts.ensure_installed --[[@as string[] ]]))
      local has_chezmoi_vim = LazyVim.has("chezmoi.vim")
      vim.api.nvim_create_autocmd("FileType", {
        callback = function(ev)
          local lang = vim.treesitter.language.get_lang(ev.match)
          if not vim.tbl_contains(installed, lang) then
            return
          end
          -- highlight
          if not (has_chezmoi_vim and ev.match:find("chezmoitmpl")) then
            pcall(vim.treesitter.start)
          end
          -- indent
          vim.bo[ev.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
        end,
      })
    end,
  },
  {
    "nvim-treesitter/nvim-treesitter",
    opts = { ensure_installed = { "mermaid", "groovy" } },
  },

  {
    "OXY2DEV/helpview.nvim",
    ft = "help",
    dependencies = {
      "nvim-treesitter/nvim-treesitter",
      opts = { ensure_installed = { "vimdoc" } },
    },
    keys = {
      { "<leader>uH", "<cmd>Helpview Toggle<cr>", desc = "Helpview" },
    },
    opts = {
      preview = {
        icon_provider = "mini",
      },
    },
    config = function(_, opts)
      require("helpview").setup(opts)

      vim.api.nvim_create_autocmd("FileType", {
        group = vim.api.nvim_create_augroup("helpview_fix_lazy", { clear = true }),
        pattern = "help",
        once = true,
        callback = function()
          vim.cmd("Helpview attach")
        end,
      })
    end,
  },

  {
    "fei6409/log-highlight.nvim",
    event = "BufRead *.log",
    ft = "log",
    opts = {},
  },
}
