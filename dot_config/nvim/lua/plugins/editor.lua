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

  {
    "echasnovski/mini.operators",
    event = "VeryLazy",
    -- https://github.com/echasnovski/mini.operators/blob/76ac9104d9773927053ea4eb12fc78ccbb5be813/doc/mini-operators.txt#L131
    opts = {
      -- gr -> cr (LazyVim use `gr` for lsp references, `cr` for remote flash by default)
      replace = { prefix = "cr" }, -- Replace text with register
      -- gx -> cx
      exchange = { prefix = "cx" }, -- Exchange text regions
      -- gm
      multiply = { prefix = "gm" }, -- Multiply (duplicate) text
      -- g= -> ""
      evaluate = { prefix = "" }, -- Evaluate text and replace with output
      -- gs -> ""
      sort = { prefix = "" }, -- Sort text
    },
  },

  -- https://github.com/doctorfree/nvim-lazyman/blob/bb4091c962e646c5eb00a50eca4a86a2d43bcb7c/lua/ecovim/config/plugins.lua#L373
  {
    "folke/flash.nvim",
    -- stylua: ignore
    keys = {
      -- r -> <space> (since `cr` is used for replace with register in mini.operators)
      -- https://github.com/rileyshahar/dotfiles/blob/ce20b2ea474f20e4eb7493e84c282645e91a36aa/nvim/lua/plugins/movement.lua#L99
      { "<space>", mode = "o", function() require("flash").remote() end, desc = "Remote Flash" },
    },
  },

  -- TODO unify the keybindings of https://github.com/vifm/vifm and neo-tree.nvim (or telescope-file-browser.nvim)
  -- https://www.lazyvim.org/plugins/editor#neo-treenvim
  -- https://github.com/craftzdog/dotfiles-public/blob/bf837d867b1aa153cbcb2e399413ec3bdcce112b/.config/nvim/lua/plugins/editor.lua#L58

  -- TODO add flash treesitter `S` when enabled LazyVim Extras - leap
}
