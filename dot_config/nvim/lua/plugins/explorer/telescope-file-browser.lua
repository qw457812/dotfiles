local hijack_netrw = vim.g.user_hijack_netrw == "telescope-file-browser.nvim"

return {
  -- https://github.com/craftzdog/dotfiles-public/blob/bf837d867b1aa153cbcb2e399413ec3bdcce112b/.config/nvim/lua/plugins/editor.lua#L58
  {
    "nvim-telescope/telescope.nvim",
    optional = true,
    dependencies = {
      {
        "nvim-telescope/telescope-file-browser.nvim",
        init = function(plugin)
          if hijack_netrw then
            U.explorer.load_on_directory(plugin.name)
          end
        end,
      },
    },
    keys = {
      {
        "<leader>'",
        function()
          local dir_icon, dir_icon_hl = require("mini.icons").get("default", "directory")
          require("telescope").extensions.file_browser.file_browser({
            path = "%:p:h",
            cwd = "%:p:h",
            grouped = true,
            select_buffer = true,
            hidden = true,
            respect_gitignore = false,
            hide_parent_dir = true,
            dir_icon = dir_icon,
            dir_icon_hl = dir_icon_hl,
            -- initial_mode = "normal",
          })
        end,
        desc = "File Browser (Buffer Dir)",
      },
    },
    opts = function(_, opts)
      local actions = require("telescope.actions")
      local action_state = require("telescope.actions.state")
      local fb_actions = require("telescope._extensions.file_browser.actions")

      opts.extensions = vim.tbl_deep_extend("force", opts.extensions or {}, {
        file_browser = {
          -- theme = "ivy",
          hijack_netrw = hijack_netrw,
          initial_mode = "normal",
          mappings = {
            ["i"] = {
              ["<bs>"] = false,
            },
            ["n"] = {
              ["g"] = false,
              ["h"] = fb_actions.goto_parent_dir,
              ["g."] = fb_actions.toggle_hidden,
              ["l"] = actions.select_default,
              ["c"] = false,
              ["a"] = fb_actions.create,
              ["/"] = function()
                -- filter
                vim.cmd("startinsert")
              end,
              --- If the prompt is empty, close the Telescope window. Otherwise, clear the prompt.
              --- https://github.com/nvim-telescope/telescope-file-browser.nvim/blob/c5a14e0550699a7db575805cdb9ddc969ba0f1f5/lua/telescope/_extensions/file_browser/actions.lua#L845
              ["<esc>"] = function(prompt_bufnr)
                local current_picker = action_state.get_current_picker(prompt_bufnr)
                if current_picker:_get_prompt() == "" then
                  actions.close(prompt_bufnr)
                else
                  -- clear filter
                  -- vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("dd", true, false, true), "tn", false)
                  current_picker:reset_prompt()
                end
              end,
              -- ["d"] = false,
              -- ["dd"] = fb_actions.remove,
              -- ["y"] = false,
              -- ["yy"] = fb_actions.copy,
              ["m"] = false,
              ["x"] = fb_actions.move,
              ["e"] = false,
              ["'h"] = fb_actions.goto_home_dir,
              ["w"] = false,
              ["'w"] = fb_actions.goto_cwd,
            },
          },
        },
      })

      LazyVim.on_load("telescope.nvim", function()
        require("telescope").setup(opts)
        require("telescope").load_extension("file_browser")
      end)
    end,
  },
}
