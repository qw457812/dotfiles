return {
  -- https://www.chezmoi.io/user-guide/tools/editor/#use-chezmoi-with-vim
  -- https://github.com/rayandrew/dotnvim/blob/8bec4783182dcd59519fa226129b5cb047b12696/lua/rayandrew/plugins/editor.lua#L173
  -- https://github.com/NeverALegend/mac-dots/blob/6669ec73c8410e3139b7187a2ed212d57b5bdd7e/dot_config/nvim/lua/legend/plugins/chezmoi.lua#L36
  -- ~/.local/share/nvim/lazy/LazyVim/lua/lazyvim/plugins/extras/editor/refactoring.lua
  -- ~/.local/share/nvim/lazy/LazyVim/lua/lazyvim/plugins/ui.lua
  -- ~/.local/share/nvim/lazy/LazyVim/lua/lazyvim/plugins/extras/coding/copilot-chat.lua
  {
    "xvzc/chezmoi.nvim",
    event = { "BufReadPre", "BufNewFile" },
    dependencies = { "nvim-lua/plenary.nvim" },
    keys = {
      {
        "<leader>f.",
        function()
          require("telescope").extensions.chezmoi.find_files()
        end,
        desc = "Find Chezmoi Source Dotfiles",
      },
    },
    opts = {
      edit = {
        watch = true, -- automatically apply changes on save by `:ChezmoiEdit` and telescope integration
        force = false,
      },
      notification = {
        on_open = true,
        on_apply = true,
        on_watch = false, -- note: `watch = true` above won't work if set `on_watch = true` here
      },
      telescope = {
        select = { "<CR>" },
      },
    },
    config = function(_, opts)
      require("chezmoi").setup(opts)
      -- treat all files in chezmoi source directory as chezmoi files
      -- automatically apply changes on files under chezmoi source path: ~/.local/share/chezmoi/*
      vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
        pattern = { os.getenv("HOME") .. "/.local/share/chezmoi/*" },
        callback = function()
          vim.schedule(require("chezmoi.commands.__edit").watch)
        end,
      })
      -- telescope integration
      if LazyVim.has("telescope.nvim") then
        LazyVim.on_load("telescope.nvim", function()
          require("telescope").load_extension("chezmoi")
        end)
      end
    end,
  },

  -- TODO alker0/chezmoi.vim for syntax highlighting
  -- https://github.com/kalocsaibotond/dotfiles/blob/73996ccc05ec53e565250c447e6c1e0d2fb7ef32/home/dot_config/nvim/lua/plugins/chezmoi.lua#L3
}
