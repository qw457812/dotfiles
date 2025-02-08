if vim.fn.executable("zoxide") == 0 then
  return {}
end

return {
  {
    "folke/snacks.nvim",
    optional = true,
    keys = function(_, keys)
      if LazyVim.pick.picker.name == "snacks" then
        -- stylua: ignore
        table.insert(keys, { "<leader>fz", function() Snacks.picker.zoxide() end, desc = "Zoxide" })
      end
    end,
  },

  -- https://github.com/Matt-FTW/dotfiles/blob/dd62c1c26ef480bb58a13de971e8418ec7181010/.config/nvim/lua/plugins/extras/editor/telescope/zoxide.lua
  {
    "nvim-telescope/telescope.nvim",
    optional = true,
    -- dependencies = { "jvgrootveld/telescope-zoxide" },
    dependencies = { "qw457812/telescope-zoxide" }, -- fork without breaking changes
    keys = {
      {
        "<leader>fz",
        function()
          local mini_icons = require("mini.icons")
          local utils = require("telescope.utils")
          local get_status = require("telescope.state").get_status
          local strings = require("plenary.strings")
          local truncate, strdisplaywidth = strings.truncate, strings.strdisplaywidth

          require("telescope").extensions.zoxide.list({
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
            -- previewer = require("telescope.previewers").vim_buffer_cat.new({}),
            previewer = U.telescope.previewers.tree(),
            path_display = function(opts, path) -- fork only
              local transformed_path = vim.trim(U.path.shorten(path))

              -- dir icon
              local icon, icon_hl = mini_icons.get("directory", path)
              icon = icon .. " "

              -- truncate
              local calc_result_length = function(truncate_len)
                local status = get_status(vim.api.nvim_get_current_buf())
                local len = vim.api.nvim_win_get_width(status.layout.results.winid)
                  - status.picker.selection_caret:len()
                  - 2
                return type(truncate_len) == "number" and len - truncate_len or len
              end
              local truncate_len = nil
              if opts.__length == nil then
                opts.__length = calc_result_length(truncate_len)
              end
              if opts.__prefix == nil then
                opts.__prefix = 0
              end
              transformed_path = icon
                .. truncate(transformed_path, opts.__length - opts.__prefix - strdisplaywidth(icon), nil, -1)

              -- dim parent directories
              local tail = utils.path_tail(path)
              local path_style = {
                { { 0, #icon }, icon_hl },
                { { #icon, #transformed_path - #tail }, "Comment" },
              }
              return transformed_path, path_style
            end,
          })
        end,
        desc = "Zoxide",
      },
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
                LazyVim.info("Directory changed to " .. U.path.home_to_tilde(selection.path), { title = "Zoxide" })
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
    "folke/snacks.nvim",
    optional = true,
    opts = function(_, opts)
      table.insert(opts.dashboard.preset.keys, 10, {
        action = LazyVim.has("telescope-zoxide") and ":Telescope zoxide list" or ":lua Snacks.picker.zoxide()",
        desc = "Zoxide",
        icon = " ",
        key = "z",
      })
    end,
  },

  -- {
  --   "goolord/alpha-nvim",
  --   optional = true,
  --   opts = function(_, dashboard)
  --     local button = dashboard.button("z", " " .. " Zoxide", "<cmd> Telescope zoxide list <cr>")
  --     button.opts.hl = "AlphaButtons"
  --     button.opts.hl_shortcut = "AlphaShortcut"
  --     table.insert(dashboard.section.buttons.val, 10, button)
  --   end,
  -- },
  -- {
  --   "echasnovski/mini.starter",
  --   optional = true,
  --   opts = function(_, opts)
  --     local items = {
  --       {
  --         name = "Zoxide",
  --         action = "Telescope zoxide list",
  --         section = string.rep(" ", 22) .. "Telescope",
  --       },
  --     }
  --     vim.list_extend(opts.items, items)
  --   end,
  -- },
  -- {
  --   "nvimdev/dashboard-nvim",
  --   optional = true,
  --   opts = function(_, opts)
  --     local zoxide = {
  --       action = "Telescope zoxide list",
  --       desc = " Zoxide",
  --       icon = " ",
  --       key = "z",
  --     }
  --     zoxide.desc = zoxide.desc .. string.rep(" ", 43 - #zoxide.desc)
  --     zoxide.key_format = "  %s"
  --     table.insert(opts.config.center, 10, zoxide)
  --   end,
  -- },
}
