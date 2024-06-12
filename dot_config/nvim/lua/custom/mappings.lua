---@type MappingsTable
local M = {}

M.general = {
  n = {
    -- [";"] = { ":", "enter command mode", opts = { nowait = true } },
    -- my | https://nvchad.com/docs/config/mappings
    -- [":"] = { ";", "repeat previous f, t, F or T movement (swap ; and :)", opts = { nowait = true } },

    ["H"] = { "^", "Start of line"},
    ["L"] = { "$", "End of line"},

    ["<leader>q"] = { ":qa <CR>", "Quit" },
    ["<leader>Q"] = { ":q! <CR>", "Quit without save" },
    ["<leader>fs"] = { "<cmd> w <CR>", "Save file" },
    -- ["<leader>x"] = { "<cmd> x <CR>", "Save file and quit" },

    ["<leader>D"] = { ":w !diff % - <CR>", "View diff before save", opts = { silent = true } },

    ["<leader>tz"] = { ":ZenMode <CR>", "Toggle Zen Mode", opts = { silent = true } },
    ["<leader>tw"] = { ":set wrap! <CR>", "Toggle line wrapping", opts = { silent = true } },
    ["<leader>T"] = { ":Translate ZH <CR>", "Translate current line", opts = { silent = true } },
    -- ["<leader>tw"] = { "mmviw:Translate ZH <CR>`m", "Translate current word", opts = { silent = true } },
    ["<leader>rr"] = { ":RnvimrToggle <CR>", "Toggle Ranger", opts = { silent = true } },
  },
  i = {
  },
  v = {
    ["H"] = { "^", "Start of line"},
    ["L"] = { "$", "End of line"},

    ["<leader>T"] = { "mm:Translate ZH <CR>`m", "Translate", opts = { silent = true } },
  },
  o = {
    ["H"] = { "^", "Start of line"},
    ["L"] = { "$", "End of line"},
  },
}

-- https://azamuddin.com/en/blog/050623-setting-up-copilot-on-nvchad
M.copilot = {
  i = {
    ["<C-l>"] = {
      function()
        vim.fn.feedkeys(vim.fn['copilot#Accept'](), '')
      end,
      "Copilot Accept",
      {replace_keycodes = true, nowait=true, silent=true, expr=true, noremap=true}
    },
    -- https://github.com/orgs/community/discussions/8105#discussioncomment-3486946
    -- ["<C-l>"] = { 'copilot#Accept("<CR>")', "Copilot Accept", opts = { silent = true, expr = true } }, -- not work good
    ["<C-j>"] = { 'copilot#Next()', "Copilot Next", opts = { silent = true, expr = true } },
    ["<C-k>"] = { 'copilot#Previous()', "Copilot Previous", opts = { silent = true, expr = true } },
  }
}
-- more keybinds!

return M
