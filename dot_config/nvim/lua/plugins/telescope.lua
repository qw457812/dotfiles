return {
  {
    "nvim-telescope/telescope.nvim",
    dependencies = {
      -- https://www.chezmoi.io/user-guide/tools/editor/#use-chezmoi-with-vim
      -- choose one of xvzc/chezmoi.nvim or GianniBYoung/chezmoi-telescope.nvim, not both
      -- note that `../config/autocmds.lua` use xvzc/chezmoi.nvim no matter which one chosen here
      { "xvzc/chezmoi.nvim", dependencies = { "nvim-lua/plenary.nvim" } },
      -- { "GianniBYoung/chezmoi-telescope.nvim" },
    },
    -- https://www.lazyvim.org/configuration/examples
    -- https://github.com/folke/dot/blob/master/nvim/lua/plugins/telescope.lua
    -- https://github.com/craftzdog/dotfiles-public/blob/master/.config/nvim/lua/plugins/editor.lua
    keys = {
      {
        "<leader>fp",
        function()
          require("telescope.builtin").find_files({ cwd = require("lazy.core.config").options.root })
        end,
        desc = "Find Plugin File",
      },
      {
        "<leader>fl",
        function()
          local files = {} ---@type table<string, string>
          for _, plugin in pairs(require("lazy.core.config").plugins) do
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
        end,
        desc = "Find Lazy Plugin Spec",
      },
      {
        "<leader>fz",
        function()
          local telescope = require("telescope")
          -- depends on the chosen above
          if LazyVim.has("chezmoi-telescope.nvim") then
            -- by GianniBYoung/chezmoi-telescope.nvim
            telescope.extensions.chezmoi.dotfiles()
          else
            -- by xvzc/chezmoi.nvim
            telescope.extensions.chezmoi.find_files()
          end
        end,
        desc = "Find Chezmoi Dotfiles",
      },
    },
    opts = {
      defaults = {
        layout_strategy = "horizontal",
        layout_config = { prompt_position = "top" },
        sorting_strategy = "ascending",
        winblend = 0,
      },
    },
    -- https://github.com/LazyVim/LazyVim/issues/283#issuecomment-1433352997
    config = function(_, opts)
      local telescope = require("telescope")
      telescope.setup(opts)
      -- load xvzc/chezmoi.nvim or GianniBYoung/chezmoi-telescope.nvim, both named "chezmoi"
      telescope.load_extension("chezmoi")
    end,
  },
}
