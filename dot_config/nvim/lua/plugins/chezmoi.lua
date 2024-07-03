-- require lazyvim.plugins.extras.util.chezmoi

-- do not overwrite <leader>fc if lazyvim.plugins.extras.util.chezmoi not enabled
if not LazyVim.has("chezmoi.nvim") or vim.fn.executable("chezmoi") == 0 then
  return {}
end

---@param target string
local function chezmoi_edit(target)
  require("chezmoi.commands").edit({ targets = { target } })
end

---@param targets? string|string[]
---@return string[]
local function chezmoi_list(targets)
  targets = targets or {}
  return require("chezmoi.commands").list({ targets = targets })
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
            require("fzf-lua").fzf_exec(chezmoi_list(), {
              actions = {
                ["default"] = function(selected)
                  chezmoi_edit("~/" .. selected[1])
                end,
              },
            })
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

            -- https://github.com/nvim-telescope/telescope.nvim/wiki/Configuration-Recipes#performing-an-arbitrary-command-by-extending-existing-find_files-picker
            -- see: ~/.local/share/nvim/lazy/chezmoi.nvim/lua/telescope/_extensions/chezmoi.lua
            require("telescope.builtin").find_files({
              prompt_title = "Config files",
              cwd = config_dir,
              attach_mappings = function(prompt_bufnr, map)
                local edit_action = function()
                  actions.close(prompt_bufnr)
                  local selection = action_state.get_selected_entry()
                  chezmoi_edit(config_dir .. "/" .. selection.value)
                end

                actions.select_default:replace(edit_action)
                return true
              end,
            })
          elseif LazyVim.pick.picker.name == "fzf" then
            require("fzf-lua").fzf_exec(chezmoi_list(config_dir), {
              actions = {
                ["default"] = function(selected)
                  chezmoi_edit("~/" .. selected[1])
                end,
              },
            })
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
