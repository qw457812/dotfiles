return {
  -- https://github.com/folke/dot/blob/master/nvim/lua/plugins/telescope.lua
  {
    "ibhagwan/fzf-lua",
    optional = true,
    keys = {
      {
        "<leader>fP",
        LazyVim.pick("files", { cwd = require("lazy.core.config").options.root }),
        desc = "Find Plugin File",
      },
      {
        "<leader>sP",
        function()
          -- local dirs = { "~/dot/nvim/lua/plugins", "~/projects/LazyVim/lua/lazyvim/plugins" }
          -- local dirs = { "~/.config/nvim/lua/plugins", "~/Projects/github/LazyVim/lua/lazyvim/plugins" } -- full extras
          local dirs = {
            "~/.config/nvim/lua/plugins",
            require("lazy.core.config").options.root .. "/LazyVim/lua/lazyvim/plugins",
          }
          require("fzf-lua").live_grep({
            filespec = "-- " .. table.concat(vim.tbl_values(dirs), " "),
            search = "/",
            formatter = "path.filename_first",
          })
        end,
        desc = "Find Lazy Plugin Spec",
      },
    },
  },
  -- TODO should not add keys if `LazyVim.pick.want() == "fzf"`
  -- https://www.lazyvim.org/configuration/examples
  -- https://github.com/craftzdog/dotfiles-public/blob/master/.config/nvim/lua/plugins/editor.lua
  {
    "nvim-telescope/telescope.nvim",
    optional = true,
    keys = {
      {
        "<leader>fP",
        function()
          require("telescope.builtin").find_files({
            cwd = require("lazy.core.config").options.root,
          })
        end,
        desc = "Find Plugin File",
      },
      {
        "<leader>sP",
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
