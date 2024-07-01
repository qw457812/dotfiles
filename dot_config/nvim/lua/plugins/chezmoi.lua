-- require lazyvim.plugins.extras.util.chezmoi
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
            require("fzf-lua").fzf_exec(require("chezmoi.commands").list({}), {
              actions = {
                ["default"] = function(selected)
                  require("chezmoi.commands").edit({ targets = { "~/" .. selected[1] } })
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
            -- local chezmoi_source_dir = "~/.local/share/chezmoi"
            -- local dirs = { chezmoi_source_dir .. "/dot_config/nvim", chezmoi_source_dir .. "/symlinks/lazyvim" }
            -- require("telescope.builtin").find_files({ search_dirs = dirs })

            -- https://github.com/nvim-telescope/telescope.nvim/wiki/Configuration-Recipes#performing-an-arbitrary-command-by-extending-existing-find_files-picker
            -- see: ~/.local/share/nvim/lazy/chezmoi.nvim/lua/telescope/_extensions/chezmoi.lua
            require("telescope.builtin").find_files({
              prompt_title = "Config files",
              cwd = config_dir,
              attach_mappings = function(prompt_bufnr, map)
                local actions = require("telescope.actions")
                local action_state = require("telescope.actions.state")
                local chezmoi_commands = require("chezmoi.commands")

                local edit_action = function()
                  actions.close(prompt_bufnr)
                  local selection = action_state.get_selected_entry()
                  chezmoi_commands.edit({
                    targets = config_dir .. "/" .. selection.value,
                  })
                end

                actions.select_default:replace(edit_action)
                return true
              end,
            })
          elseif LazyVim.pick.picker.name == "fzf" then
            require("fzf-lua").fzf_exec(require("chezmoi.commands").list({ targets = config_dir }), {
              actions = {
                ["default"] = function(selected)
                  require("chezmoi.commands").edit({ targets = { "~/" .. selected[1] } })
                end,
              },
            })
          end
        end,
        desc = "Find Config File",
      },
    },
  },
}
