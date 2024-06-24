local Config = require("lazy.core.config")

-- https://github.com/folke/dot/blob/master/nvim/lua/plugins/telescope.lua
-- ~/.local/share/nvim/lazy/LazyVim/lua/lazyvim/plugins/extras/util/project.lua
local pick_plugin_file = function()
  if LazyVim.pick.picker.name == "telescope" then
    require("telescope.builtin").find_files({ cwd = Config.options.root })
  elseif LazyVim.pick.picker.name == "fzf" then
    require("fzf-lua").files({ cwd = Config.options.root })
  end
end

local pick_lazy_plugin_spec = function()
  if LazyVim.pick.picker.name == "telescope" then
    local files = {} ---@type table<string, string>
    for _, plugin in pairs(Config.plugins) do
      repeat
        if plugin._.module then
          local info = vim.loader.find(plugin._.module)[1]
          if info then
            files[info.modpath] = info.modpath
          end
        end
        plugin = plugin._.super
      until not plugin
    end
    require("telescope.builtin").live_grep({
      default_text = "/",
      search_dirs = vim.tbl_values(files),
    })
  elseif LazyVim.pick.picker.name == "fzf" then
    local dirs = { "~/.config/nvim/lua/plugins", Config.options.root .. "/LazyVim/lua/lazyvim/plugins" }
    require("fzf-lua").live_grep({
      filespec = "-- " .. table.concat(vim.tbl_values(dirs), " "),
      search = "/",
      formatter = "path.filename_first",
    })
  end
end

return {
  {
    "ibhagwan/fzf-lua",
    optional = true,
    keys = {
      { "<leader>fP", pick_plugin_file, desc = "Find Plugin File" },
      { "<leader>sP", pick_lazy_plugin_spec, desc = "Find Lazy Plugin Spec" },
    },
  },
  -- https://www.lazyvim.org/configuration/examples
  -- https://github.com/craftzdog/dotfiles-public/blob/master/.config/nvim/lua/plugins/editor.lua
  {
    "nvim-telescope/telescope.nvim",
    optional = true,
    keys = {
      { "<leader>fP", pick_plugin_file, desc = "Find Plugin File" },
      { "<leader>sP", pick_lazy_plugin_spec, desc = "Find Lazy Plugin Spec" },
    },
    opts = {
      defaults = {
        layout_strategy = "horizontal",
        layout_config = { prompt_position = "top" },
        sorting_strategy = "ascending",
        winblend = 0,
      },
    },
  },

  -- LSP Keymaps
  -- https://www.lazyvim.org/plugins/lsp#%EF%B8%8F-customizing-lsp-keymaps
  -- ~/.local/share/nvim/lazy/LazyVim/lua/lazyvim/plugins/extras/editor/telescope.lua
  -- ~/.local/share/nvim/lazy/LazyVim/lua/lazyvim/plugins/extras/editor/fzf.lua
  -- ~/.local/share/nvim/lazy/LazyVim/lua/lazyvim/plugins/extras/editor/inc-rename.lua
  {
    "neovim/nvim-lspconfig",
    opts = function()
      local keys = require("lazyvim.plugins.lsp.keymaps").get()
      -- TODO map <cr> to lsp_references if no definition, like `gd` in vscode and idea
      if LazyVim.pick.want() == "telescope" then
        -- stylua: ignore
        vim.list_extend(keys, {
          { "<cr>", function() require("telescope.builtin").lsp_definitions({ reuse_win = true }) end, desc = "Goto Definition", has = "definition" },
        })
      elseif LazyVim.pick.want() == "fzf" then
        -- stylua: ignore
        vim.list_extend(keys, {
          { "<cr>", "<cmd>FzfLua lsp_definitions     jump_to_single_result=true ignore_current_line=true<cr>", desc = "Goto Definition", has = "definition" },
        })
      end
    end,
  },
}
