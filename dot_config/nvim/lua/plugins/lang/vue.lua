if not LazyVim.has_extra("lang.vue") then
  return {}
end

---@type LazySpec
return {
  {
    "neovim/nvim-lspconfig",
    opts = function(_, opts)
      -- see:
      -- - https://github.com/neovim/nvim-lspconfig/commit/221bc7b
      -- - https://github.com/LazyVim/LazyVim/pull/6174
      opts.servers.vue_ls = opts.servers.volar
      opts.servers.volar = nil
    end,
  },
}

-- TODO: check https://github.com/LazyVim/LazyVim/pull/6238
