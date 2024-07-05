return {
  {
    "echasnovski/mini.operators",
    event = "VeryLazy",
    vscode = true,
    -- https://github.com/echasnovski/mini.operators/blob/76ac9104d9773927053ea4eb12fc78ccbb5be813/doc/mini-operators.txt#L131
    opts = {
      -- gr (LazyVim use `gr` for lsp references, and `cr` for remote flash by default)
      replace = { prefix = "cr" }, -- Replace text with register
      -- gx
      exchange = { prefix = "cx" }, -- Exchange text regions
      -- gm (note that `cmm` is used for `c%` by custom helix-style mappings)
      multiply = { prefix = "cd" }, -- Multiply (duplicate) text
      -- g=
      evaluate = { prefix = "" }, -- Evaluate text and replace with output
      -- gs
      sort = { prefix = "" }, -- Sort text
    },
  },

  {
    "folke/flash.nvim",
    optional = true,
    -- stylua: ignore
    keys = {
      -- r -> <space> (since `cr` is used for replace with register in mini.operators)
      { "r", mode = "o", false },
      { "R", mode = { "o", "x" }, false },
      -- https://github.com/rileyshahar/dotfiles/blob/ce20b2ea474f20e4eb7493e84c282645e91a36aa/nvim/lua/plugins/movement.lua#L99
      { "<space>", mode = "o", function() require("flash").remote() end, desc = "Remote Flash" },
      { "<tab>", mode = { "o", "x" }, function() require("flash").treesitter_search() end, desc = "Treesitter Search" },
    },
  },
}
