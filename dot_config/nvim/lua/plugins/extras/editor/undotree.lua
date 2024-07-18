if not LazyVim.has("telescope.nvim") then
  return {}
end

return {
  -- https://github.com/Matt-FTW/dotfiles/blob/9c7bd1b3737e3ced5bd97e6df803eaecb7692451/.config/nvim/lua/plugins/extras/editor/telescope/undotree.lua
  -- https://github.com/appelgriebsch/Nv/blob/56b0ff93056d031666049c9a0d0b5f7b5c36b958/lua/plugins/extras/editor/undo-mode.lua
  -- {
  --   "nvim-telescope/telescope.nvim",
  --   optional = true,
  --   dependencies = { "debugloop/telescope-undo.nvim" },
  --   keys = {
  --     { "<leader>su", "<cmd>Telescope undo<cr>", desc = "Undo History" },
  --   },
  --   opts = {
  --     extensions = {
  --       undo = {
  --         -- side_by_side = true,
  --         -- layout_strategy = "vertical",
  --         layout_config = {
  --           vertical = {
  --             preview_cutoff = 20,
  --             preview_height = function(_, _, max_lines)
  --               return math.max(max_lines - 12, math.floor(max_lines * 0.65))
  --             end,
  --           },
  --           horizontal = {
  --             preview_width = function(_, max_columns, _)
  --               return math.max(max_columns - 45, math.floor(max_columns * 0.65))
  --             end,
  --           },
  --         },
  --       },
  --     },
  --   },
  --   config = function(_, opts)
  --     require("telescope").setup(opts)
  --     require("telescope").load_extension("undo")
  --   end,
  -- },

  {
    "debugloop/telescope-undo.nvim",
    dependencies = { "nvim-telescope/telescope.nvim" },
    keys = {
      { "<leader>su", "<cmd>Telescope undo<cr>", desc = "Undo History" },
    },
    opts = {
      extensions = {
        undo = {
          -- side_by_side = true,
          -- layout_strategy = "vertical",
          layout_config = {
            vertical = {
              preview_cutoff = 20,
              preview_height = function(_, _, max_lines)
                return math.max(max_lines - 12, math.floor(max_lines * 0.65))
              end,
            },
            horizontal = {
              preview_width = function(_, max_columns, _)
                return math.max(max_columns - 45, math.floor(max_columns * 0.65))
              end,
            },
          },
        },
      },
    },
    config = function(_, opts)
      LazyVim.on_load("telescope.nvim", function()
        require("telescope").setup(opts)
        require("telescope").load_extension("undo")
      end)
    end,
  },
}
