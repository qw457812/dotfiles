if not U.path.CHEZMOI then
  return {}
end

---@type LazySpec
return {
  -- Both plugins detect template filetypes; use gotmpl instead of *.chezmoitmpl.
  { "alker0/chezmoi.vim", enabled = false },

  {
    "dpezto/chezmoi-template.nvim",
    lazy = false,
    ---@module "chezmoi-template"
    ---@param opts chezmoi-template.Config
    opts = function(_, opts)
      local has_chezmoi_nvim = LazyVim.has("chezmoi.nvim")

      return U.extend_tbl(opts, {
        source_dir = U.path.CHEZMOI,
        apply = {
          -- The existing chezmoi.nvim integration already watches source files.
          on_save = not has_chezmoi_nvim,
        },
        keymaps = { enabled = true },
        encryption = { enabled = true },
      } --[[@as chezmoi-template.Config]])
    end,
  },

  {
    "nvim-treesitter/nvim-treesitter",
    opts = { ensure_installed = { "gotmpl" } },
  },

  {
    "saghen/blink.cmp",
    optional = true,
    dependencies = {
      "dpezto/chezmoi-template.nvim",
      shell_command_editor = true,
    },
    opts = {
      sources = {
        default = { "chezmoi" },
        providers = {
          chezmoi = {
            name = "chezmoi",
            module = "chezmoi-template.blink",
          },
        },
      },
    },
  },
}
