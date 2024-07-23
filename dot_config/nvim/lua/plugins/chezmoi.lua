-- require lazyvim.plugins.extras.util.chezmoi
-- do not overwrite <leader>fc if lazyvim.plugins.extras.util.chezmoi not enabled
if not LazyVim.has_extra("util.chezmoi") or vim.fn.executable("chezmoi") == 0 then
  return {}
end

---@param targets? string|string[]
local function fzf_chezmoi(targets)
  local chezmoi = require("chezmoi.commands")
  local results = chezmoi.list({
    targets = targets or {},
    -- see: ~/.local/share/nvim/lazy/chezmoi.nvim/lua/telescope/_extensions/find_files.lua
    args = { "--include", "files" }, -- exclude directories
  })
  local opts = {
    fzf_opts = {},
    fzf_colors = true,
    actions = {
      ["default"] = function(selected)
        if not vim.tbl_isempty(selected) then
          chezmoi.edit({
            targets = "~/" .. selected[1],
          })
        end
      end,
    },
  }
  require("fzf-lua").fzf_exec(results, opts)
end

return {
  {
    "xvzc/chezmoi.nvim",
    optional = true,
    keys = {
      { "<leader>sz", false },
      {
        "<leader>f.",
        function()
          if LazyVim.pick.picker.name == "telescope" then
            require("telescope").extensions.chezmoi.find_files()
          elseif LazyVim.pick.picker.name == "fzf" then
            fzf_chezmoi()
          end
        end,
        desc = "Find Chezmoi Source Dotfiles",
      },
      {
        "<leader>fc",
        function()
          local config_dir = vim.fn.stdpath("config")
          if LazyVim.pick.picker.name == "telescope" then
            local actions = require("telescope.actions")
            local action_state = require("telescope.actions.state")
            local chezmoi = require("chezmoi.commands")

            -- https://github.com/nvim-telescope/telescope.nvim/wiki/Configuration-Recipes#performing-an-arbitrary-command-by-extending-existing-find_files-picker
            -- see: ~/.local/share/nvim/lazy/chezmoi.nvim/lua/telescope/_extensions/chezmoi.lua
            require("telescope.builtin").find_files({
              prompt_title = "Config Files",
              cwd = config_dir,
              attach_mappings = function(prompt_bufnr)
                local edit_action = function()
                  actions.close(prompt_bufnr)
                  local selection = action_state.get_selected_entry()
                  if selection then
                    chezmoi.edit({
                      targets = config_dir .. "/" .. selection.value,
                    })
                  end
                end

                actions.select_default:replace(edit_action)
                return true
              end,
            })
          elseif LazyVim.pick.picker.name == "fzf" then
            fzf_chezmoi(config_dir)
          end
        end,
        desc = "Find Config File",
      },
    },
  },

  {
    "ibhagwan/fzf-lua",
    optional = true,
    keys = { { "<leader>fc", false } },
  },
  {
    "nvim-telescope/telescope.nvim",
    optional = true,
    keys = { { "<leader>fc", false } },
  },
}
