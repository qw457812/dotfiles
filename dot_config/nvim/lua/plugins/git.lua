return {
  {
    "LazyVim/LazyVim",
    opts = function()
      -- -- fix cursor position when using `git commit --verbose` with auto-fold
      -- vim.api.nvim_create_autocmd("FileType", {
      --   pattern = "gitcommit",
      --   callback = function(ev)
      --     local win = vim.fn.bufwinid(ev.buf)
      --     vim.defer_fn(function()
      --       if vim.api.nvim_buf_is_valid(ev.buf) and vim.api.nvim_get_current_win() == win then
      --         vim.api.nvim_win_set_cursor(win, { 1, 0 })
      --         -- vim.cmd("startinsert")
      --         vim.cmd("normal! zR")
      --       end
      --     end, 50)
      --   end,
      -- })
      vim.api.nvim_create_autocmd("FileType", {
        pattern = "gitcommit",
        callback = function(ev)
          if not vim.fn.fnamemodify(ev.file, ":t") == "COMMIT_EDITMSG" then
            return
          end
          local win = vim.fn.bufwinid(ev.buf)
          vim.schedule(function()
            if vim.api.nvim_get_current_buf() == ev.buf and vim.api.nvim_get_current_win() == win then
              vim.api.nvim_win_set_cursor(win, { 1, 0 })
              vim.cmd("startinsert")
            end
          end)
        end,
      })
      vim.api.nvim_create_autocmd("BufWritePost", {
        pattern = "COMMIT_EDITMSG",
        callback = function(ev)
          if vim.bo[ev.buf].filetype ~= "gitcommit" then
            return
          end
          if vim.g.user_close_key then
            vim.api.nvim_feedkeys(vim.keycode(vim.g.user_close_key), "m", false)
          else
            vim.cmd([[quit]])
          end
        end,
      })
    end,
  },

  {
    "folke/snacks.nvim",
    keys = function(_, keys)
      if LazyVim.pick.picker.name == "snacks" then
        -- stylua: ignore
        vim.list_extend(keys, {
          { "<leader>gb", function() Snacks.picker.git_branches({ cwd = LazyVim.root.git() }) end, desc = "Git Branches" },
          { "<leader>gB", function() Snacks.picker.git_log_line() end, desc = "Git Blame Line" },
          -- { "<leader>gc", function() Snacks.picker.git_log({ cwd = LazyVim.root.git() }) end, desc = "Git Log" },
          { "<leader>gd", function() Snacks.picker.git_diff({ cwd = LazyVim.root.git() }) end, desc = "Git Diff (hunks)" },
          { "<leader>gs", function() Snacks.picker.git_status({ cwd = LazyVim.root.git() }) end, desc = "Git Status" },
          { "<leader>gS", function() Snacks.picker.git_stash({ cwd = LazyVim.root.git() }) end, desc = "Git Stash" },
        })
      end
    end,
    ---@module "snacks"
    ---@type snacks.Config
    opts = {
      picker = {
        previewers = {
          diff = {
            builtin = false,
            cmd = { "delta", "--file-style", "omit ", "--hunk-header-style", "omit" },
          },
          git = {
            builtin = false,
          },
        },
      },
    },
  },

  {
    "folke/snacks.nvim",
    keys = function(_, keys)
      vim.list_extend(keys, {
        {
          "<leader>gO",
          function()
            ---@diagnostic disable-next-line: missing-fields
            Snacks.gitbrowse({ what = "permalink" })
            U.stop_visual_mode()
          end,
          mode = { "n", "x" },
          desc = "Git Browse (open)",
        },
        {
          "<leader>gY",
          function()
            ---@diagnostic disable-next-line: missing-fields
            Snacks.gitbrowse({
              what = "permalink",
              open = function(url)
                vim.fn.setreg(vim.v.register, url)
                U.stop_visual_mode()
                LazyVim.info(url, { title = "Copied URL" })
              end,
              notify = false,
            })
          end,
          mode = { "n", "x" },
          desc = "Git Browse (copy)",
        },
      })
    end,
    ---@module "snacks"
    ---@type snacks.Config
    opts = {
      lazygit = {
        win = vim.g.user_is_termux and {
          height = vim.o.lines,
          width = vim.o.columns,
          border = "none",
        } or nil,
      },
    },
  },

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

  {
    "sindrets/diffview.nvim",
    cmd = { "DiffviewOpen", "DiffviewFileHistory" },
    keys = {
      { "<leader>gv", "<cmd>DiffviewOpen<CR>", desc = "Diff View" },
      { "<leader>gD", "<cmd>DiffviewFileHistory<CR>", desc = "Diff Repo (Diff View)" },
      { "<leader>gF", "<cmd>DiffviewFileHistory %<CR>", desc = "File History (Diff View)" },
    },
    ---@param opts DiffviewConfig
    opts = function(_, opts)
      local actions = require("diffview.actions")

      LazyVim.extend(opts, "keymaps.view", {
        { "n", "q", actions.close, { desc = "Close" } },
      })
      LazyVim.extend(opts, "keymaps.file_panel", {
        { "n", "q", actions.close, { desc = "Close" } },
        {
          "n",
          "<Esc>",
          function()
            if not U.keymap.clear_ui_esc() then
              actions.close()
              vim.cmd("wincmd =")
            end
          end,
          desc = "Clear UI or Close",
        },
        {
          "n",
          "l",
          function()
            actions.select_entry()
            if vim.g.user_is_termux then
              actions.close()
              vim.cmd("wincmd =")
            end
          end,
          { desc = "Open" },
        },
      })
      LazyVim.extend(opts, "keymaps.file_history_panel", {
        { "n", "q", "<cmd>DiffviewClose<CR>", { desc = "Close" } },
      })

      return U.extend_tbl(opts, {
        enhanced_diff_hl = true,
        view = {
          default = {
            -- FIXME: dropbar
            winbar_info = true,
          },
          merge_tool = {
            layout = "diff3_mixed",
          },
          file_history = {
            winbar_info = true,
          },
        },
        hooks = {
          view_opened = function(view)
            vim.t[view.tabpage].user_diffview = true
            if view.class:name() == "DiffView" then
              actions.toggle_files() -- Close DiffView:FilePanel initially
            end
          end,
        },
      })
    end,
    specs = {
      {
        "NeogitOrg/neogit",
        optional = true,
        opts = { integrations = { diffview = true } },
      },
    },
  },

  {
    "NeogitOrg/neogit",
    cmd = "Neogit",
    keys = function()
      ---@param opts OpenOpts|nil
      local open = function(opts)
        opts = vim.tbl_deep_extend("force", { cwd = LazyVim.root.git() }, opts or {})
        require("neogit").open(opts)
      end

      return {
        { "<Leader>gn", open, desc = "Neogit (Root Dir)" },
        { "<Leader>gN", "<Cmd>Neogit<CR>", desc = "Neogit (cwd)" },
        {
          "<Leader>gc",
          function()
            open({ [1] = "commit" })
            vim.api.nvim_create_autocmd("FileType", {
              pattern = "NeogitPopup",
              once = true,
              callback = function()
                vim.api.nvim_feedkeys(vim.keycode("c"), "m", false)
              end,
            })
          end,
          desc = "Commit (Neogit)",
        },
      }
    end,
    opts = function(_, opts)
      return U.extend_tbl(opts, {
        disable_signs = true,
        telescope_sorter = function()
          if LazyVim.has("telescope-fzf-native.nvim") then
            return require("telescope").extensions.fzf.native_fzf_sorter()
          end
        end,
        integrations = {
          -- diffview = LazyVim.has("diffview.nvim"),
          telescope = LazyVim.pick.picker.name == "telescope",
          fzf_lua = LazyVim.pick.picker.name == "fzf",
        },
      })
    end,
    specs = {
      {
        "catppuccin",
        optional = true,
        opts = { integrations = { neogit = true } },
      },
    },
  },
}
