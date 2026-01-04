if not LazyVim.has_extra("lang.nix") then
  return {}
end

local has_nix = vim.fn.executable("nix") == 1

---@type LazySpec
return {
  {
    "neovim/nvim-lspconfig",
    ---@type PluginLspOpts
    opts = {
      ---@type table<string, lazyvim.lsp.Config|boolean>
      servers = {
        nil_ls = {
          enabled = has_nix,
          settings = {
            ["nil"] = {
              formatting = {
                command = { "alejandra" },
              },
            },
          },
        },
      },
    },
  },
  {
    "mason-org/mason.nvim",
    opts = {
      ensure_installed = has_nix and { "alejandra" } or nil,
    },
  },
  {
    "stevearc/conform.nvim",
    optional = true,
    ---@module "conform"
    ---@param opts conform.setupOpts
    opts = function(_, opts)
      opts.formatters_by_ft = opts.formatters_by_ft or {}
      opts.formatters_by_ft.nix = nil -- using nil_ls
    end,
  },
}
