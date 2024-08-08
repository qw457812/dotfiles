return {
  {
    "echasnovski/mini.operators",
    event = "VeryLazy",
    vscode = true,
    -- https://github.com/chrisgrieser/.config/blob/181def43f255a502670af318297289f4e8f49c83/nvim/lua/plugins/editing-support.lua#L108
    -- https://github.com/JulesNP/nvim/blob/36b04ae414b98e67a80f15d335c73744606a33d7/lua/plugins/mini.lua#L656
    keys = {
      { "cR", "cr$", desc = "Replace to end of line", remap = true },
      { "cX", "cx$", desc = "Exchange to end of line", remap = true },
      { "cD", "cd$", desc = "Multiply to end of line", remap = true },
    },
    -- https://github.com/echasnovski/mini.operators/blob/76ac9104d9773927053ea4eb12fc78ccbb5be813/doc/mini-operators.txt#L131
    opts = {
      -- gr (LazyVim use `gr` for lsp references, `cr` for remote flash by default, and `gss` conflicts with `gs` + `s` for flash)
      -- note: `vim.opt.timeoutlen` has increased from 300 to 500 for `cr` and `cR` since which-key v3
      replace = { prefix = "" }, -- Replace text with register
      -- gx
      exchange = { prefix = "" }, -- Exchange text regions
      -- gm (note that `cmm` is used for `c%` by custom helix-style mappings)
      multiply = { prefix = "" }, -- Multiply (duplicate) text
      -- g=
      -- evaluate = { prefix = "" }, -- Evaluate text and replace with output
      -- gs
      sort = { prefix = "" }, -- Sort text
    },
    config = function(_, opts)
      local operators = require("mini.operators")
      operators.setup(opts)
      -- do not delay `v_c`
      operators.make_mappings("replace", { textobject = "cr", line = "crr", selection = "" }) -- disable `v_cr` since we have `v_p`
      operators.make_mappings("exchange", { textobject = "cx", line = "cxx", selection = "X" }) -- https://github.com/tommcdo/vim-exchange#mappings
      operators.make_mappings("multiply", { textobject = "cd", line = "cdd", selection = "" })
    end,
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
