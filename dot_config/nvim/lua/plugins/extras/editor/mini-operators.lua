return {
  {
    "echasnovski/mini.operators",
    shell_command_editor = true,
    dependencies = {
      {
        "rachartier/tiny-glimmer.nvim",
        optional = true,
        opts = {
          support = { substitute = { enabled = true } },
        },
      },
      { "y3owk1n/undo-glow.nvim", optional = true },
    },
    vscode = true,
    -- https://github.com/chrisgrieser/.config/blob/9bc8b38e0e9282b6f55d0b6335f98e2bf9510a7c/nvim/lua/plugin-specs/mini-operators.lua
    -- https://github.com/JulesNP/nvim/blob/cfcda023287fb58e584d970c1b71330262eaf3ed/lua/plugins/mini.lua#L725
    keys = {
      { "s", desc = "Replace Operator" },
      { "S", "s$", desc = "Replace to EoL", remap = true },
      { "cx", desc = "Exchange Operator" },
      { "cX", "cx$", desc = "Exchange to EoL", remap = true }, -- `vim.opt.timeoutlen` has increased from 300 to 500 for `cX` since which-key v3
      { "X", mode = "x", desc = "Exchange Selection" },
      { "sd", mode = { "n", "x" }, desc = "Multiply Operator" },
      {
        "sdd",
        function()
          vim.o.operatorfunc = "v:lua.require'util.keymap'.smart_duplicate_line"
          return "g@l"
        end,
        expr = true,
        desc = "Duplicate Line",
      },
      { "sD", "sd$", desc = "Multiply to EoL", remap = true },
      { "g=", mode = { "n", "x" }, desc = "Evaluate Operator" },
      { "so", mode = { "n", "x" }, desc = "Sort Operator" },
    },
    opts = {
      -- candidates: s gr gs gp cr cp yr
      -- conflicts:
      -- * gr: lsp reference
      -- * cr: remote flash `o_r`
      -- * gs: lsp goto super
      -- * gss: flash
      replace = { prefix = "" },
      exchange = { prefix = "" },
      -- conflicts: `gmm`/`cmm` is used for `g%`/`c%` by custom helix-style mapping `o_mm`
      multiply = { prefix = "" },
      sort = { prefix = "so" },
    },
    config = function(_, opts)
      local operators = require("mini.operators")
      operators.setup(opts)

      if LazyVim.has("tiny-glimmer.nvim") then
        vim.keymap.set("n", "s", function()
          require("tiny-glimmer.support.substitute").substitute_cb({ register = vim.v.register })
          return operators.replace()
        end, { expr = true, replace_keycodes = false, silent = true, desc = "Replace Operator" })
        vim.keymap.set("n", "ss", "s_", { remap = true, silent = true, desc = "Replace Line" })
      elseif LazyVim.has("undo-glow.nvim") then
        Snacks.util.set_hl({ UgSubstitute = { fg = "#000000", bg = Snacks.util.color("DiagnosticHint"), bold = true } }) -- TodoBgNOTE
        vim.keymap.set("n", "s", function()
          require("undo-glow").highlight_changes(require("undo-glow.utils").merge_command_opts("UgSubstitute"))
          return operators.replace()
        end, { expr = true, replace_keycodes = false, silent = true, desc = "Replace Operator" })
        vim.keymap.set("n", "ss", "s_", { remap = true, silent = true, desc = "Replace Line" })
      else
        operators.make_mappings("replace", { textobject = "s", line = "ss", selection = "" }) -- disable `v_s` since we have `v_P`
      end
      -- do not delay `v_c`
      operators.make_mappings("exchange", { textobject = "cx", line = "cxx", selection = "X" }) -- https://github.com/tommcdo/vim-exchange#mappings
      -- Do not set `multiply` mapping for line, since we use our own, as
      -- multiply's transformation function only supports pre-duplication
      -- changes, which prevents us from doing post-duplication cursor
      -- movements.
      operators.make_mappings("multiply", { textobject = "sd", line = "", selection = "sd" })
    end,
  },

  {
    "folke/flash.nvim",
    optional = true,
    keys = {
      { "s", mode = { "n", "x", "o" }, false },
      { "S", mode = { "n", "o", "x" }, false },
    },
    specs = {
      {
        "folke/snacks.nvim",
        opts = {
          picker = {
            win = {
              input = {
                keys = { ["s"] = false },
              },
            },
          },
        },
      },
    },
  },
}
