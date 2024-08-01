if not LazyVim.has("telescope.nvim") or vim.fn.executable("zoxide") == 0 then
  return {}
end

local pick = function()
  local telescope = require("telescope")
  local previewers = require("telescope.previewers")
  local from_entry = require("telescope.from_entry")
  local utils = require("telescope.utils")

  -- https://github.com/petobens/dotfiles/blob/0e216cdf8048859db5cbec0a1bc5b99d45479817/nvim/lua/plugin-config/telescope_config.lua#L784
  local tree_previewer = previewers.new_termopen_previewer({
    title = "Tree Preview",
    get_command = function(entry)
      local p = from_entry.path(entry, true, false)
      if p == nil or p == "" then
        return
      end
      local command
      local ignore_glob = ".DS_Store|.git|.svn|.idea|.vscode|node_modules"
      if vim.fn.executable("eza") == 1 then
        command = {
          "eza",
          "--all",
          "--level=2",
          "--group-directories-first",
          "--ignore-glob=" .. ignore_glob,
          "--git-ignore",
          "--tree",
          "--color=always",
          "--color-scale",
          "all",
          "--icons=always",
          "--long",
          "--time-style=iso",
          "--git",
          "--no-permissions",
          "--no-user",
        }
      else
        command = { "tree", "-a", "-L", "2", "-I", ignore_glob, "-C", "--dirsfirst" }
      end
      return utils.flatten({ command, "--", utils.path_expand(p) })
    end,
    -- ~/.local/share/nvim/lazy/telescope.nvim/lua/telescope/previewers/buffer_previewer.lua
    scroll_fn = function(self, direction)
      if not self.state then
        return
      end
      -- local input = direction > 0 and string.char(0x05) or string.char(0x19)
      -- local input = direction > 0 and [[]] or [[]]
      -- https://github.com/nvim-telescope/telescope.nvim/issues/2933#issuecomment-1958504220
      local input = vim.api.nvim_replace_termcodes(direction > 0 and "<C-e>" or "<C-y>", true, false, true)
      local count = math.abs(direction)
      vim.api.nvim_win_call(vim.fn.bufwinid(self.state.termopen_bufnr), function()
        vim.cmd([[normal! ]] .. count .. input)
      end)
    end,
  })

  -- ~/.local/share/nvim/lazy/telescope-zoxide/lua/telescope/_extensions/zoxide/list.lua
  telescope.extensions.zoxide.list({
    -- layout_config = {
    --   horizontal = {
    --     preview_width = function(_, max_columns, _)
    --       if max_columns < 150 then
    --         return math.floor(max_columns * 0.4)
    --       else
    --         return math.floor(max_columns * 0.5)
    --       end
    --     end,
    --   },
    -- },
    -- previewer = previewers.vim_buffer_cat.new({}),
    previewer = tree_previewer,
  })
end

-- https://github.com/Matt-FTW/dotfiles/blob/dd62c1c26ef480bb58a13de971e8418ec7181010/.config/nvim/lua/plugins/extras/editor/telescope/zoxide.lua
-- https://github.com/jvgrootveld/telescope-zoxide/issues/4#issuecomment-877110133
return {
  -- https://github.com/craftzdog/dotfiles-public/blob/master/.config/nvim/lua/plugins/editor.lua
  {
    "nvim-telescope/telescope.nvim",
    optional = true,
    -- dependencies = { "jvgrootveld/telescope-zoxide" },
    dependencies = { "qw457812/telescope-zoxide" }, -- fork without breaking changes
    keys = {
      { "<leader>fz", pick, desc = "Zoxide" },
    },
    opts = function(_, opts)
      opts.extensions = vim.tbl_deep_extend("force", opts.extensions or {}, {
        zoxide = {
          prompt_title = "Zoxide",
          -- show_score = false, -- fork only
          mappings = {
            default = {
              action = function(selection)
                vim.cmd.cd(selection.path)
                -- https://github.com/jvgrootveld/telescope-zoxide/issues/23
                -- alternative: https://github.com/jvgrootveld/telescope-zoxide/issues/21#issuecomment-1506606584
                vim.fn.system({ "zoxide", "add", selection.path })
              end,
              after_action = function(selection)
                LazyVim.info(
                  "Directory changed to " .. require("util.path").replace_home_with_tilde(selection.path),
                  { title = "Zoxide" }
                )
                -- vim.cmd.edit(selection.path)
                -- require("neo-tree.command").execute({ dir = selection.path })
                require("telescope.builtin").find_files({ cwd = selection.path })
              end,
            },
          },
        },
      })

      LazyVim.on_load("telescope.nvim", function()
        require("telescope").setup(opts)
        require("telescope").load_extension("zoxide")
      end)
    end,
  },

  {
    "goolord/alpha-nvim",
    optional = true,
    opts = function(_, dashboard)
      local button = dashboard.button("z", " " .. " Zoxide", "<cmd> Telescope zoxide list <cr>")
      button.opts.hl = "AlphaButtons"
      button.opts.hl_shortcut = "AlphaShortcut"
      table.insert(dashboard.section.buttons.val, 10, button)
    end,
  },

  {
    "echasnovski/mini.starter",
    optional = true,
    opts = function(_, opts)
      local items = {
        {
          name = "Zoxide",
          action = "Telescope zoxide list",
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
        action = "Telescope zoxide list",
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
