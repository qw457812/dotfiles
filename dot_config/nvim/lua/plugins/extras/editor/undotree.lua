return {
  -- https://github.com/Matt-FTW/dotfiles/blob/9c7bd1b3737e3ced5bd97e6df803eaecb7692451/.config/nvim/lua/plugins/extras/editor/telescope/undotree.lua
  -- https://github.com/appelgriebsch/Nv/blob/56b0ff93056d031666049c9a0d0b5f7b5c36b958/lua/plugins/extras/editor/undo-mode.lua
  -- https://github.com/duckien2346/nvim-config/blob/0c48b6c97dcff9ed62d1ac63e9d3c7668d55b529/lua/plugins/life-saver/telescope-undo.lua
  -- https://github.com/mikedfunk/dots/blob/2dc43acd139c553a576b1a9e66cccec1add0e871/.config/nvim/lua/plugins/group_editor.lua#L119
  {
    "nvim-telescope/telescope.nvim",
    optional = true,
    dependencies = { "debugloop/telescope-undo.nvim" },
    keys = {
      { "<leader>su", "<cmd>Telescope undo<cr>", desc = "Undo History" },
    },
    opts = function(_, opts)
      local undo_actions = require("telescope-undo.actions")

      --- https://github.com/emmanueltouzery/nvim_config/blob/cac11a0bdc4ac2fb535189f18fe5cf07538e7810/init.lua#L162
      ---@param undo_action fun(prompt_bufnr:number):fun():string[]?
      ---@return fun(prompt_bufnr:number):fun():string[]?
      local function notify_wrap(undo_action)
        return function(prompt_bufnr)
          return function()
            local lines = undo_action(prompt_bufnr)()
            if lines then
              LazyVim.info("Copied " .. #lines .. " lines", { title = "Undo History" })
            end
            return lines
          end
        end
      end
      local yank_additions_with_notify = notify_wrap(undo_actions.yank_additions)
      local yank_deletions_with_notify = notify_wrap(undo_actions.yank_deletions)

      opts.extensions = vim.tbl_deep_extend("force", opts.extensions or {}, {
        undo = {
          side_by_side = true,
          layout_strategy = "vertical",
          layout_config = {
            preview_cutoff = 1, -- preview should always show
            vertical = {
              preview_height = function(_, _, max_lines)
                return math.max(max_lines - 12, math.floor(max_lines * 0.65))
              end,
            },
            horizontal = {
              preview_width = function(_, max_columns, _)
                -- related to `entry_format` opt
                return math.max(max_columns - 45, math.floor(max_columns * 0.65))
              end,
            },
          },
          mappings = {
            -- ~/.local/share/nvim/lazy/telescope-undo.nvim/lua/telescope/_extensions/undo.lua
            i = {
              ["<S-cr>"] = false,
              ["<C-cr>"] = false,
              ["<C-y>"] = false,
              ["<C-r>"] = false,
              ["<cr>"] = yank_additions_with_notify,
              ["<C-r>a"] = yank_additions_with_notify,
              ["<C-r>d"] = yank_deletions_with_notify,
              ["<C-r>r"] = undo_actions.restore,
            },
            n = {
              -- alternative: ["y"] = require("telescope.actions").nop,
              ["y"] = false,
              ["Y"] = false,
              ["u"] = false,
              ["<cr>"] = yank_additions_with_notify,
              ["ya"] = yank_additions_with_notify,
              ["yd"] = yank_deletions_with_notify,
              ["gr"] = undo_actions.restore,
            },
          },
        },
      })
    end,
    config = function(_, opts)
      require("telescope").setup(opts)
      require("telescope").load_extension("undo")
    end,
  },
}
