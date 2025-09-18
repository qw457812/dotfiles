---@type LazySpec
return {
  {
    "nvim-treesitter/nvim-treesitter",
    ---@module "lazyvim"
    ---@param opts lazyvim.TSConfig
    opts = function(_, opts)
      -- Setup highlight on our own in favor of chezmoi templates
      opts.highlight.enable = false
      local has_chezmoi_vim = LazyVim.has("chezmoi.vim")
      vim.api.nvim_create_autocmd("FileType", {
        callback = function(ev)
          if LazyVim.treesitter.have(ev.match) and not (has_chezmoi_vim and ev.match:find("chezmoitmpl")) then
            pcall(vim.treesitter.start)
          end
        end,
      })
    end,
  },
  {
    "nvim-treesitter/nvim-treesitter",
    ---@type lazyvim.TSConfig|{}
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
    ---@type helpview.config|{}
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
