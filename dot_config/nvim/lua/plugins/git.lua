return {
  {
    "lewis6991/gitsigns.nvim",
    optional = true,
    opts = function(_, opts)
      opts.attach_to_untracked = true

      local on_attach = opts.on_attach or function(_) end
      opts.on_attach = function(buffer)
        on_attach(buffer)

        ---@module 'gitsigns'
        local gs = package.loaded.gitsigns

        local function map(mode, l, r, desc)
          vim.keymap.set(mode, l, r, { buffer = buffer, desc = desc })
        end

        -- HACK: redraw to update the signs
        local function redraw()
          vim.defer_fn(function()
            Snacks.util.redraw(vim.api.nvim_get_current_win())
          end, 500)
        end

        -- mini.diff like mappings
        map("n", "gh", function()
          gs.stage_hunk()
          redraw()
        end, "Stage Hunk")
        map("v", "gh", function()
          gs.stage_hunk({ vim.fn.line("."), vim.fn.line("v") })
          redraw()
        end, "Stage Hunk")
        map("o", "gh", "<cmd>Gitsigns select_hunk<CR>", "Hunk Textobj")
        map("n", "gH", gs.reset_hunk, "Reset Hunk")
        map("v", "gH", function()
          gs.reset_hunk({ vim.fn.line("."), vim.fn.line("v") })
        end, "Reset Hunk")
        -- https://github.com/chrisgrieser/.config/blob/9bc8b38e0e9282b6f55d0b6335f98e2bf9510a7c/nvim/lua/plugin-specs/gitsigns.lua#L46
        map("n", "<leader>go", function()
          gs.toggle_deleted()
          gs.toggle_word_diff()
          gs.toggle_linehl()
          redraw()
        end, "Toggle Diff Overlay (GitSigns)")

        map("n", "<leader>ghh", function()
          gs.stage_buffer()
          redraw()
        end, "Stage Buffer")
        map("n", "<leader>ghu", function()
          gs.undo_stage_hunk()
          redraw()
        end, "Undo Stage Hunk")
        map("n", "<leader>gD", function()
          gs.diffthis("~")
          if vim.g.user_close_key then
            map("n", vim.g.user_close_key, function()
              vim.keymap.del("n", vim.g.user_close_key, { buffer = buffer })
              vim.cmd.only()
            end, "Close Diff (Gitsigns)")
          end
        end, "Diff This ~")
        map("n", "<leader>g?", gs.toggle_current_line_blame, "Toggle Blame Line (GitSigns)")
      end
    end,
  },
  {
    "echasnovski/mini.diff",
    optional = true,
    keys = function(_, keys)
      -- HACK: redraw to update the signs
      local function redraw(delay)
        vim.defer_fn(function()
          Snacks.util.redraw(vim.api.nvim_get_current_win())
        end, delay or 500)
      end

      vim.list_extend(keys, {
        -- {
        --   "gh",
        --   function()
        --     redraw() -- not working
        --     return require("mini.diff").operator("apply")
        --   end,
        --   expr = true,
        --   silent = true,
        --   desc = "Apply hunks",
        --   mode = { "n", "x" },
        -- },
        {
          "<leader>go",
          function()
            require("mini.diff").toggle_overlay(0)
            redraw(200)
          end,
          desc = "Toggle mini.diff overlay",
        },
      })
    end,
    opts = function()
      -- copied from: https://github.com/echasnovski/mini.nvim/issues/1319#issuecomment-2761528147
      Snacks.util.set_hl({
        MiniDiffOverAdd = { bg = "#104010" }, -- regular green
        MiniDiffOverChange = { bg = "#600000" }, -- saturated red
        MiniDiffOverChangeBuf = { bg = "#006000" }, -- saturated green
        MiniDiffOverContext = { bg = "#401010" }, -- regular red
        MiniDiffOverContextBuf = "MiniDiffOverAdd",
        MiniDiffOverDelete = "MiniDiffOverContext",
      })
    end,
  },
}
