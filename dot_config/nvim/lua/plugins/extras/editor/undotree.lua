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
      { "<leader>su", "<cmd>Telescope undo<cr>", desc = "Undo Tree" },
    },
    opts = function(_, opts)
      local undo_actions = require("telescope-undo.actions")
      local undo_previewer = require("telescope-undo.previewer")

      --- https://github.com/emmanueltouzery/nvim_config/blob/cac11a0bdc4ac2fb535189f18fe5cf07538e7810/init.lua#L162
      ---@param undo_action fun(prompt_bufnr:number):fun():string[]?
      ---@return fun(prompt_bufnr:number):fun():string[]?
      local function notify_wrap(undo_action)
        return function(prompt_bufnr)
          return function()
            local lines = undo_action(prompt_bufnr)()
            if lines then
              LazyVim.info("Copied " .. #lines .. " lines", { title = "Undo Tree" })
            end
            return lines
          end
        end
      end
      local yank_additions_with_notify = notify_wrap(undo_actions.yank_additions)
      local yank_deletions_with_notify = notify_wrap(undo_actions.yank_deletions)

      opts.extensions = vim.tbl_deep_extend("force", opts.extensions or {}, {
        undo = {
          -- -- side_by_side = true,
          -- -- use `--side-by-side` or `--paging never` to wrap lines
          -- use_custom_command = {
          --   "bash",
          --   "-c",
          --   -- "echo '$DIFF' | delta --file-style omit --hunk-header-style omit --paging never", -- can't scroll, see hack below
          --   "echo '$DIFF' | delta --file-style omit --hunk-header-style omit --side-by-side",
          -- },
          layout_strategy = "vertical",
          layout_config = {
            preview_cutoff = 1, -- preview should always show
            vertical = {
              width = function(_, max_columns, _)
                return vim.g.user_is_termux and max_columns or math.floor(max_columns * 0.9)
              end,
              height = function(_, _, max_lines)
                return vim.g.user_is_termux and max_lines or math.floor(max_lines * 0.95)
              end,
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
            i = {
              ["<S-cr>"] = false,
              ["<C-cr>"] = false,
              ["<C-y>"] = false,
              ["<C-r>"] = false,
              ["<cr>"] = yank_additions_with_notify,
              -- ["<C-r>a"] = yank_additions_with_notify,
              ["<C-r>d"] = yank_deletions_with_notify,
              ["<C-r>r"] = undo_actions.restore,
            },
            n = {
              -- alternative: ["y"] = require("telescope.actions").nop,
              ["y"] = false,
              ["Y"] = false,
              ["u"] = false,
              ["<cr>"] = yank_additions_with_notify,
              -- ["ya"] = yank_additions_with_notify,
              ["yd"] = yank_deletions_with_notify,
              ["gr"] = undo_actions.restore,
            },
          },
        },
      })

      if vim.fn.executable("delta") == 1 then
        -- HACK: scroll for `delta --paging never`
        ---@diagnostic disable-next-line: unused-local
        function undo_previewer.get_previewer(o)
          return U.telescope.previewers.never_paging_term({
            -- copied from:
            -- https://github.com/debugloop/telescope-undo.nvim/blob/2971cc9f193ec09e0c5de3563f99cbea16b63f10/lua/telescope-undo/previewer.lua
            -- https://github.com/rachartier/tiny-code-action.nvim/blob/b389735000946367e357e006102c11b46ee808f3/lua/tiny-code-action/backend/delta.lua#L80
            get_command = function(entry, _)
              return {
                "bash",
                "-c",
                "echo '"
                  .. entry.value.diff:gsub("'", [['"'"']])
                  .. string.rep("\n", vim.o.lines) -- HACK: to prevent `Process exited` message
                  .. "' | delta --file-style omit --hunk-header-style omit --paging never",
              }
            end,
          })
        end
      end

      -- NOTE:
      -- 1. The `setup` and `load_extension` below can be skipped, but tab completions `:Telescope |<tab>` will not be available right away.
      --    https://github.com/nvim-telescope/telescope.nvim/blob/10b8a82b042caf50b78e619d92caf0910211973d/README.md?plain=1#L598
      -- 2. Seems to be that `load_extension` needs to be called after the `setup`.
      --    https://github.com/LazyVim/LazyVim/issues/283#issuecomment-1433352997
      -- 3. The reason of using `opts` function instead of `config` function:
      --    If you have multiple specs for the same plugin, then all `opts` will be evaluated, but only the last `config`.
      --    https://github.com/LazyVim/LazyVim/pull/4122#issuecomment-2241563662
      LazyVim.on_load("telescope.nvim", function()
        require("telescope").setup(opts)
        require("telescope").load_extension("undo")
      end)
    end,
  },
}
