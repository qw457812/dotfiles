---@param bufnr integer?
---@return boolean
local function is_mise_config(bufnr)
  local filepath = vim.fs.normalize(vim.api.nvim_buf_get_name(bufnr or 0))
  local filename = vim.fn.fnamemodify(filepath, ":t")
  return filename:match("^%.?mise.*%.toml$") ~= nil
    or filepath:match("/%.?mise/config%.toml$") ~= nil
    or filepath:match("/%.?mise/config%.local%.toml$") ~= nil
    or filepath:match("/%.?mise/config%.[^/]+%.toml$") ~= nil
    or filepath:match("/%.config/mise/mise%.toml$") ~= nil
    or filepath:match("/%.config/mise/mise%.local%.toml$") ~= nil
    or filepath:match("/%.?mise/conf%.d/[^/]+%.toml$") ~= nil
end

---@type LazySpec
return {
  {
    "neovim/nvim-lspconfig",
    ---@param opts PluginLspOpts
    opts = function(_, opts)
      if vim.fn.executable("mise") == 0 then
        return
      end

      opts.servers.mise = {
        mason = false,
        root_dir = function(bufnr, on_dir)
          if is_mise_config(bufnr) then
            on_dir(vim.fs.root(bufnr, vim.lsp.config.mise.root_markers))
          end
        end,
      }

      if LazyVim.has_extra("lang.toml") then
        opts.servers.taplo = vim.tbl_deep_extend("force", opts.servers.taplo or {}, {
          root_dir = function(bufnr, on_dir)
            if not is_mise_config(bufnr) then
              on_dir(vim.fs.root(bufnr, vim.lsp.config.taplo.root_markers))
            end
          end,
        } --[[@as lazyvim.lsp.Config]])
      end
    end,
  },

  {
    "nvim-treesitter/nvim-treesitter",
    opts = function()
      require("vim.treesitter.query").add_predicate("is-mise?", function(_, _, bufnr, _)
        return is_mise_config(tonumber(bufnr))
      end, { force = true, all = false })
    end,
  },
  {
    "nvim-treesitter/nvim-treesitter",
    opts = { ensure_installed = { "toml", "bash" } },
  },
}
