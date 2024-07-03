if not LazyVim.has("telescope.nvim") or vim.fn.executable("zoxide") == 0 then
  return {}
end

local pick = function()
  -- picker_opts | https://github.com/nvim-telescope/telescope.nvim#customization
  require("telescope").extensions.zoxide.list({
    -- layout_config = { width = 0.5, height = 0.7 },
  })
end

-- https://github.com/Matt-FTW/dotfiles/blob/dd62c1c26ef480bb58a13de971e8418ec7181010/.config/nvim/lua/plugins/extras/editor/telescope/zoxide.lua
return {
  -- ~/.local/share/nvim/lazy/LazyVim/lua/lazyvim/plugins/extras/editor/telescope.lua
  -- https://github.com/craftzdog/dotfiles-public/blob/master/.config/nvim/lua/plugins/editor.lua
  {
    "telescope.nvim",
    optional = true,
    dependencies = { "jvgrootveld/telescope-zoxide" },
    keys = {
      { "<leader>fz", pick, desc = "Zoxide" },
    },
    config = function(_, opts)
      -- see: ~/.local/share/nvim/lazy/telescope-zoxide/lua/telescope/_extensions/zoxide/config.lua
      opts.extensions = {
        zoxide = {
          prompt_title = "Zoxide",
          mappings = {
            default = {
              action = function(selection)
                vim.cmd.cd(selection.path)
              end,
              after_action = function(selection)
                print("Directory changed to " .. selection.path)
                -- vim.cmd.edit(selection.path)
                -- require("neo-tree.command").execute({ dir = selection.path })
                require("telescope.builtin").find_files({ cwd = selection.path })
              end,
            },
          },
        },
      }
      require("telescope").setup(opts)
      require("telescope").load_extension("zoxide")
    end,
  },

  {
    "goolord/alpha-nvim",
    optional = true,
    opts = function(_, dashboard)
      local button = dashboard.button("z", " " .. " Zoxide", pick)
      button.opts.hl = "AlphaButtons"
      button.opts.hl_shortcut = "AlphaShortcut"
      table.insert(dashboard.section.buttons.val, 11, button)
    end,
  },

  {
    "echasnovski/mini.starter",
    optional = true,
    opts = function(_, opts)
      local items = {
        {
          name = "Zoxide",
          action = pick,
          section = string.rep(" ", 22) .. "Telescope",
        },
      }
      vim.list_extend(opts.items, items)
    end,
  },

  {
    "nvimdev/dashboard-nvim",
    optional = true,
    opts = function(_, opts)
      local zoxide = {
        action = pick,
        desc = " Zoxide",
        icon = " ",
        key = "z",
      }

      zoxide.desc = zoxide.desc .. string.rep(" ", 43 - #zoxide.desc)
      zoxide.key_format = "  %s"

      table.insert(opts.config.center, 10, zoxide)
    end,
  },
}
