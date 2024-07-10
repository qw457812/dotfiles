if not LazyVim.has("telescope.nvim") or vim.fn.executable("zoxide") == 0 then
  return {}
end

local telescope = require("telescope")
local builtin = require("telescope.builtin")
local previewers = require("telescope.previewers")
local from_entry = require("telescope.from_entry")
local utils = require("telescope.utils")

-- https://github.com/petobens/dotfiles/blob/0e216cdf8048859db5cbec0a1bc5b99d45479817/nvim/lua/plugin-config/telescope_config.lua#L784
-- ~/.local/share/nvim/lazy/telescope.nvim/lua/telescope/previewers/buffer_previewer.lua
local less_scroll_fn = function(self, direction)
  if not self.state then
    return
  end
  -- local input = direction > 0 and string.char(0x05) or string.char(0x19) -- 0x05 -> <C-e>; 0x19 -> <C-y>
  -- local input = direction > 0 and [[]] or [[]]
  -- https://github.com/nvim-telescope/telescope.nvim/issues/2933#issuecomment-1958504220
  local input = vim.api.nvim_replace_termcodes(direction > 0 and "<C-e>" or "<C-y>", true, false, true)
  local count = math.abs(direction)
  vim.api.nvim_win_call(vim.fn.bufwinid(self.state.termopen_bufnr), function()
    vim.cmd([[normal! ]] .. count .. input)
  end)
end

-- custom previewer
local tree_previewer = previewers.new_termopen_previewer({
  title = "Tree Preview",
  get_command = function(entry)
    local p = from_entry.path(entry, true, false)
    if p == nil or p == "" then
      return
    end
    return {
      "eza",
      "--all",
      "--level=2",
      "--group-directories-first",
      "--ignore-glob=.DS_Store|.git|.svn|.idea|.vscode",
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
      utils.path_expand(p),
    }
  end,
  scroll_fn = less_scroll_fn,
})

local pick = function()
  -- picker_opts | https://github.com/nvim-telescope/telescope.nvim#customization
  -- ~/.local/share/nvim/lazy/telescope-zoxide/lua/telescope/_extensions/zoxide/list.lua
  telescope.extensions.zoxide.list({
    -- layout_config = { width = 0.5, height = 0.7 }, -- without previewer
    previewer = tree_previewer,
    -- TODO replace home directory with `~` (`path_display` not working)
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
                LazyVim.info(
                  "Directory changed to " .. require("util.path").replace_home_with_tilde(selection.path),
                  { title = "Zoxide" }
                )
                -- vim.cmd.edit(selection.path)
                -- require("neo-tree.command").execute({ dir = selection.path })
                builtin.find_files({ cwd = selection.path })
              end,
            },
          },
        },
      }
      telescope.setup(opts)
      telescope.load_extension("zoxide")
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
