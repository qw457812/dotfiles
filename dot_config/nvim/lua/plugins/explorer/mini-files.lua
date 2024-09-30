return {
  -- https://github.com/linkarzu/dotfiles-latest/blob/66c7304d34c713e8c7d6066d924ac2c3a9c0c9e8/neovim/neobean/lua/plugins/mini-files.lua
  -- https://github.com/mrjones2014/dotfiles/blob/62cd7b9c034b04daff4a2b38ad9eac0c9dcb43e1/nvim/lua/my/configure/mini_files.lua
  {
    "echasnovski/mini.files",
    optional = true,
    opts = function(_, opts)
      opts.options = vim.tbl_deep_extend("force", opts.options or {}, {
        use_as_default_explorer = vim.g.user_default_explorer == "mini.files",
      })
      opts.mappings = vim.tbl_deep_extend("force", opts.mappings or {}, {
        go_in = "",
        go_out = "",
        go_in_plus = "l", -- go_in + close explorer after opening a file
        go_out_plus = "h", -- go_out + trim right part of branch
        -- -- don't use `h`/`l` for easier cursor navigation during text edit
        -- go_in_plus = "L",
        -- go_out_plus = "H",
      })
      -- opts.windows = vim.tbl_deep_extend("force", opts.windows or {}, {
      --   width_preview = 60,
      -- })

      vim.api.nvim_create_autocmd("User", {
        pattern = "MiniFilesBufferCreate",
        callback = function(args)
          local buf_id = args.data.buf_id

          -- stylua: ignore start
          vim.keymap.set("n", "<cr>", function() require("mini.files").go_in({ close_on_file = true }) end, { buffer = buf_id, desc = "Go in plus (mini.files)" })
          vim.keymap.set("n", "<leader>fs", function() require("mini.files").synchronize() end, { buffer = buf_id, desc = "Synchronize (mini.files)" })
          vim.keymap.set("n", "<C-s>", function() require("mini.files").synchronize() end, { buffer = buf_id, desc = "Synchronize (mini.files)" })
          -- stylua: ignore end
          vim.keymap.set("n", "<leader>sr", function()
            local files = require("mini.files")
            -- works only if cursor is on the valid file system entry
            local cur_entry_path = files.get_fs_entry().path
            files.close()
            U.explorer.grug_far(vim.fs.dirname(cur_entry_path))
          end, { buffer = buf_id, desc = "Search and Replace in Directory (mini.files)" })
          -- cursor navigation during text edit
          vim.keymap.set("n", "H", "h", { buffer = buf_id, desc = "<Left>" })
          vim.keymap.set("n", "L", "l", { buffer = buf_id, desc = "<Right>" })
        end,
      })

      -- set custom bookmarks
      local set_mark = function(id, path, desc)
        MiniFiles.set_bookmark(id, path, { desc = desc })
      end
      vim.api.nvim_create_autocmd("User", {
        pattern = "MiniFilesExplorerOpen",
        callback = function()
          set_mark("c", U.path.CONFIG, "Config") -- path
          set_mark("w", vim.fn.getcwd, "cwd") -- callable
          set_mark("h", "~", "Home")
          -- stylua: ignore
          set_mark("r", function() return LazyVim.root.get({ normalize = true }) end, "Root")
          set_mark("l", U.path.LAZYVIM, "LazyVim")
          if U.path.CHEZMOI then
            set_mark("z", U.path.CHEZMOI, "Chezmoi")
          end
        end,
      })
    end,
  },
}
