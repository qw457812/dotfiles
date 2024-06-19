return {
  -- for escaping easily from insert mode
  {
    "max397574/better-escape.nvim",
    event = "InsertCharPre",
    opts = {
      mapping = { "jk", "jj", "kj", "kk" },
      timeout = 300,
    },
  },

  -- TODO unify the keybindings of https://github.com/vifm/vifm and neo-tree.nvim (or telescope-file-browser.nvim)
  -- https://www.lazyvim.org/plugins/editor#neo-treenvim
  -- https://github.com/craftzdog/dotfiles-public/blob/bf837d867b1aa153cbcb2e399413ec3bdcce112b/.config/nvim/lua/plugins/editor.lua#L58

  -- TODO flash `s`: leap-like 2-char motion
  -- https://github.com/folke/flash.nvim/issues/56
  -- https://github.com/folke/flash.nvim/issues/57
  -- https://github.com/boltlessengineer/nvim/blob/607ee0c9412be67ba127a4d50ee722be578b5d9f/lua/plugins/editor.lua#L40

  -- TODO add flash treesitter `S` when enabled LazyVim Extras - leap
}
