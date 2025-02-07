local H = {}

-- copied from: https://github.com/chrisgrieser/.config/blob/9bc8b38e0e9282b6f55d0b6335f98e2bf9510a7c/nvim/lua/personal-plugins/misc.lua#L109
function H.smartDuplicate()
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  local line = vim.api.nvim_get_current_line()

  -- FILETYPE-SPECIFIC TWEAKS
  if vim.bo.ft == "css" then
    local newLine = line
    if line:find("top:") then
      newLine = line:gsub("top:", "bottom:")
    end
    if line:find("bottom:") then
      newLine = line:gsub("bottom:", "top:")
    end
    if line:find("right:") then
      newLine = line:gsub("right:", "left:")
    end
    if line:find("left:") then
      newLine = line:gsub("left:", "right:")
    end
    line = newLine
  elseif vim.bo.ft == "javascript" or vim.bo.ft == "typescript" then
    line = line:gsub("^(%s*)if(.+{)$", "%1} else if%2")
  elseif vim.bo.ft == "lua" then
    line = line:gsub("^(%s*)if( .* then)$", "%1elseif%2")
  elseif vim.bo.ft == "zsh" or vim.bo.ft == "bash" then
    line = line:gsub("^(%s*)if( .* then)$", "%1elif%2")
  elseif vim.bo.ft == "python" then
    line = line:gsub("^(%s*)if( .*:)$", "%1elif%2")
  end

  -- INSERT DUPLICATED LINE
  vim.api.nvim_buf_set_lines(0, row, row, false, { line })

  -- MOVE CURSOR DOWN, AND TO VALUE/FIELD (IF EXISTS)
  local _, luadocFieldPos = line:find("%-%-%-@%w+ ")
  local _, valuePos = line:find("[:=][:=]? ")
  local targetCol = luadocFieldPos or valuePos or col
  vim.api.nvim_win_set_cursor(0, { row + 1, targetCol })
end

return {
  {
    "echasnovski/mini.operators",
    dependencies = {
      {
        "rachartier/tiny-glimmer.nvim",
        optional = true,
        opts = {
          support = { substitute = { enabled = true } },
        },
      },
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
      { "sdd", H.smartDuplicate, desc = "Duplicate Line" },
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
