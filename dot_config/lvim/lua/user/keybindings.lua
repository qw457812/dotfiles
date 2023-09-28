local M = {}

M.config = function()
  lvim.keys.normal_mode["<esc>"] = "<cmd>nohlsearch<cr>"
  lvim.keys.normal_mode["Y"] = "y$"
  lvim.keys.normal_mode["H"] = "^"
  lvim.keys.normal_mode["L"] = "$"
  -- lvim.keys.visual_mode["p"] = [["_dP]]

  lvim.keys.normal_mode["<leader>D"] = ":w !diff % -<cr>"

  lvim.keys.normal_mode["<leader>z"] = "<cmd>ZenMode<cr>"
  lvim.keys.normal_mode["<leader>r"] = "<cmd>RnvimrToggle<cr>"
  lvim.keys.normal_mode["<leader>tw"] = "mmviw:Translate ZH<cr>`m"
  lvim.keys.normal_mode["<leader>tt"] = ":Translate ZH<cr>"
  lvim.keys.visual_mode["<leader>t"] = "mm:Translate ZH<cr>`m"
  lvim.keys.visual_mode["H"] = "^"
  lvim.keys.visual_mode["L"] = "$"

end

return M
