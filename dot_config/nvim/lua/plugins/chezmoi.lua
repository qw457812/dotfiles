-- require lazyvim.plugins.extras.util.chezmoi
-- do not overwrite <leader>fc if lazyvim.plugins.extras.util.chezmoi not enabled
if not LazyVim.has_extra("util.chezmoi") or vim.fn.executable("chezmoi") == 0 then
  return {}
end

-- exclude directories and externals
-- see: ~/.local/share/nvim/lazy/chezmoi.nvim/lua/telescope/_extensions/find_files.lua
local chezmoi_list_args = { "--include", "files", "--exclude", "externals" }

--- pick nvim config
local pick_config = function()
  local chezmoi = require("chezmoi.commands")
  local config_dir = vim.fn.stdpath("config")
  local managed_config_files = chezmoi.list({
    targets = config_dir,
    args = { "--path-style", "absolute", unpack(chezmoi_list_args) },
  })

  if vim.tbl_isempty(managed_config_files) then
    LazyVim.pick.config_files()()
    return
  end

  if LazyVim.pick.picker.name == "telescope" then
    local actions = require("telescope.actions")
    local action_state = require("telescope.actions.state")
    local config = require("chezmoi").config

    -- https://github.com/nvim-telescope/telescope.nvim/wiki/Configuration-Recipes#performing-an-arbitrary-command-by-extending-existing-find_files-picker
    -- see: ~/.local/share/nvim/lazy/chezmoi.nvim/lua/telescope/_extensions/chezmoi.lua
    require("telescope.builtin").find_files({
      prompt_title = "Config Files",
      cwd = config_dir,
      attach_mappings = function(prompt_bufnr, map)
        -- copied from: https://github.com/xvzc/chezmoi.nvim/blob/faf61465718424696269b2647077331b3e4605f1/lua/telescope/_extensions/find_files.lua#L34
        local edit_action = function()
          actions.close(prompt_bufnr)
          local selection = action_state.get_selected_entry()
          if selection then
            chezmoi.edit({ targets = config_dir .. "/" .. selection.value })
          end
        end

        for _, v in ipairs(config.telescope.select) do
          map("i", v, "select_default")
        end

        -- it's possible that only part of nvim config files are managed with chezmoi
        -- pick all and just edit if unmanaged
        actions.select_default:replace_if(function()
          local selection = action_state.get_selected_entry()
          return selection and vim.tbl_contains(managed_config_files, config_dir .. "/" .. selection.value)
        end, edit_action)
        return true
      end,
    })
  elseif LazyVim.pick.picker.name == "fzf" then
    require("fzf-lua").files({
      cwd = config_dir,
      actions = {
        ["default"] = function(selected, opts)
          if vim.tbl_isempty(selected) then
            return
          end

          local file = require("fzf-lua.path").entry_to_file(selected[1], opts).path
          if vim.tbl_contains(managed_config_files, file) then
            chezmoi.edit({ targets = file })
          else
            require("fzf-lua.actions").file_edit(selected, opts)
          end
        end,
      },
    })
  end
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
            local chezmoi = require("chezmoi.commands")
            local results = chezmoi.list({ args = chezmoi_list_args })
            local opts = {
              prompt = " ",
              fzf_opts = {},
              fzf_colors = true,
              actions = {
                ["default"] = function(selected)
                  if not vim.tbl_isempty(selected) then
                    chezmoi.edit({ targets = "~/" .. selected[1] })
                  end
                end,
              },
              -- TODO: previewer
            }
            require("fzf-lua").fzf_exec(results, opts)
          end
        end,
        desc = "Find Chezmoi Source Dotfiles",
      },
      { "<leader>fc", pick_config, desc = "Find Config File" },
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
