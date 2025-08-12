local H = {}

function H.build_plugin(plugin)
  require("yazi.plugin").build_plugin(plugin)
end

---@type LazySpec
return {
  -- https://github.com/sxyazi/dotfiles/blob/79828c4b3f33a9b0286f2c8f5e60dcc052ace632/nvim/lua/plugins/ui.lua#L557
  -- https://github.com/mikavilpas/dotfiles/blob/4e99cc0c933abd614bd362e2555630b528ebb0fe/.config/nvim/lua/plugins/my-file-manager.lua
  {
    "mikavilpas/yazi.nvim",
    dependencies = "folke/snacks.nvim",
    cmd = "Yazi",
    keys = {
      { "<leader><cr>", mode = { "n", "v" }, "<cmd>Yazi<cr>", desc = "Yazi (Buffer Dir)" },
    },
    init = function(plugin)
      local opts = LazyVim.opts("yazi.nvim")
      if opts.open_for_directories then
        U.explorer.load_on_directory(plugin.name)
      end
    end,
    opts = function()
      vim.api.nvim_create_autocmd("TermOpen", {
        pattern = "term://*yazi*",
        callback = function(event)
          local buf = event.buf
          if vim.bo[buf].filetype ~= "yazi" then
            return
          end

          vim.b[buf].user_lualine_filename = "yazi"
          -- vim.keymap.set("t", "<esc>", "<esc>", { buffer = buf, nowait = true })
          vim.keymap.set("t", "<c-h>", "<c-h>", { buffer = buf, nowait = true })
          vim.keymap.set("t", "<c-j>", "<c-j>", { buffer = buf, nowait = true })
          vim.keymap.set("t", "<c-k>", "<c-k>", { buffer = buf, nowait = true })
          vim.keymap.set("t", "<c-l>", "<c-l>", { buffer = buf, nowait = true })
          -- after closing `show_help` by <bs>, yazi goes to normal mode
          vim.api.nvim_create_autocmd("BufEnter", {
            buffer = buf,
            callback = function()
              vim.cmd.startinsert()
            end,
          })
        end,
      })

      -- -- already done, see: https://github.com/mikavilpas/yazi.nvim/blob/d09f94e79fc0a28f7242ff94af17ca96d8a41878/lua/yazi/event_handling/yazi_event_handling.lua#L76
      -- vim.api.nvim_create_autocmd("User", {
      --   pattern = "YaziRenamedOrMoved",
      --   ---@module 'yazi'
      --   ---@param event {data: YaziNeovimEvent.YaziRenamedOrMovedData}
      --   callback = function(event)
      --     for from, to in pairs(event.data.changes) do
      --       Snacks.rename.on_rename_file(from, to)
      --     end
      --   end,
      -- })

      local picker = ({ snacks = "snacks.picker", fzf = "fzf-lua", telescope = "telescope" })[LazyVim.pick.picker.name]

      ---@module "yazi"
      ---@type YaziConfig
      return {
        open_for_directories = vim.g.user_hijack_netrw == "yazi.nvim",
        open_multiple_tabs = true,
        floating_window_scaling_factor = vim.g.user_is_termux and 1 or { height = 0.9, width = 0.9 },
        yazi_floating_window_border = vim.g.user_is_termux and "none" or nil,
        keymaps = {
          -- do not map `<tab>` or `~`, otherwise they will not be available in `shell "$SHELL" --block`
          -- see: https://github.com/mikavilpas/yazi.nvim/pull/894
          cycle_open_buffers = "<c-space>",
          open_file_in_horizontal_split = "<c-s>",
          grep_in_directory = "<c-g>",
          replace_in_directory = "<m-r>",
          open_and_pick_window = "<m-o>",
          copy_relative_path_to_selected_files = "<M-y>", -- relative to nvim current file
        },
        integrations = {
          grep_in_directory = picker,
          grep_in_selected_files = picker,
          -- -- for copy_relative_path_to_selected_files, relative to root instead of current file
          -- resolve_relative_path_implementation = function(args, get_relative_path)
          --   return get_relative_path({ selected_file = args.selected_file, source_dir = LazyVim.root() })
          -- end,
        },
      }
    end,
    -- use lazy.nvim instead of `ya pkg` as package manager
    specs = {
      {
        "yazi-rs/flavors",
        name = "yazi-flavors",
        lazy = true,
        build = function(plugin)
          require("yazi.plugin").build_flavor(plugin, { sub_dir = "catppuccin-frappe.yazi" })
        end,
      },
      {
        "yazi-rs/plugins",
        name = "yazi-plugins",
        lazy = true,
        build = function(plugin)
          local sub_dirs = {
            "smart-enter.yazi",
            "full-border.yazi",
            "chmod.yazi",
            "git.yazi",
            "vcs-files.yazi",
            "diff.yazi",
            "smart-filter.yazi",
            "mount.yazi",
            "zoom.yazi",
            "types.yazi",
          }
          for _, sub_dir in ipairs(sub_dirs) do
            require("yazi.plugin").build_plugin(plugin, { sub_dir = sub_dir })
          end
        end,
        specs = {
          {
            "folke/lazydev.nvim",
            opts = function(_, opts)
              opts.library = opts.library or {}
              table.insert(opts.library, { path = "yazi-plugins/types.yazi", words = { "ya%.emit", "ya%.sync" } })
            end,
          },
        },
      },
      { "Rolv-Apneseth/starship.yazi", lazy = true, build = H.build_plugin },
      { "dedukun/bookmarks.yazi", lazy = true, build = H.build_plugin },
    },
  },

  LazyVim.pick.picker.name == "snacks"
      and {
        "mikavilpas/yazi.nvim",
        ---@type YaziConfig
        opts = {
          integrations = {
            picker_add_copy_relative_path_action = "snacks.picker",
          },
        },
        specs = {
          {
            "folke/snacks.nvim",
            ---@module "snacks"
            ---@type snacks.Config
            opts = {
              picker = {
                win = {
                  input = {
                    keys = {
                      yazi_copy_relative_path = {
                        "<M-y>",
                        function(self)
                          require("lazy").load({ plugins = { "yazi.nvim" } })
                          self:execute("yazi_copy_relative_path") -- relative to alternate-file, same behavior as copy_relative_path_to_selected_files
                          local paths = vim.fn.getreg(require("yazi").config.clipboard_register)
                          LazyVim.info(paths, { title = "Copied Path" })
                        end,
                        mode = { "n", "i" },
                        desc = "yazi_copy_relative_path",
                      },
                    },
                  },
                },
              },
            },
          },
        },
      }
    or nil,
}
