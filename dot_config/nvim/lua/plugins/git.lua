---@type LazySpec
return {
  {
    "LazyVim/LazyVim",
    opts = function()
      local commit_ft = { "gitcommit", "svn" }
      local commit_filename = { "COMMIT_EDITMSG", "svn-commit.tmp" }
      vim.api.nvim_create_autocmd("FileType", {
        pattern = commit_ft,
        callback = function(ev)
          if not vim.list_contains(commit_filename, vim.fn.fnamemodify(ev.file, ":t")) then
            return
          end
          local win = vim.fn.bufwinid(ev.buf)
          vim.schedule(function()
            if vim.api.nvim_get_current_buf() == ev.buf and vim.api.nvim_get_current_win() == win then
              vim.api.nvim_win_set_cursor(win, { 1, 0 })
              if vim.api.nvim_get_current_line():match("^%s*$") then
                vim.cmd("startinsert")
              end
            end
          end)
        end,
      })
      -- see also: https://github.com/willothy/nvim-config/blob/b5db7b8b7fe6258770c98f12337d6954a56b95e7/lua/configs/terminal/flatten.lua#L93-L105
      vim.api.nvim_create_autocmd("BufWritePost", {
        pattern = commit_filename,
        callback = function(ev)
          if not vim.list_contains(commit_ft, vim.bo[ev.buf].filetype) then
            return
          end
          local win = vim.fn.bufwinid(ev.buf)
          vim.schedule(function()
            if vim.api.nvim_get_current_buf() == ev.buf and vim.api.nvim_get_current_win() == win then
              if vim.g.user_close_key then
                vim.cmd.normal(vim.keycode(vim.g.user_close_key))
              else
                vim.cmd([[quit]])
              end
            end
          end)
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
          {
            "<leader>gS",
            function()
              Snacks.picker.git_stash({
                cwd = LazyVim.root.git(),
                previewers = {
                  git = {
                    args = {}, -- overwrite `opts.picker.previewers.git.args`
                  },
                },
              })
            end,
            desc = "Git Stash",
          },
        })
      end
      return keys
    end,
    ---@module "snacks"
    ---@type snacks.Config
    opts = {
      picker = {
        previewers = {
          diff = {
            builtin = false,
            cmd = { "delta", "--file-style", "omit", "--hunk-header-style", "omit" },
          },
          git = {
            builtin = false,
            args = { "-c", "delta.file-style=omit", "-c", "delta.hunk-header-style=omit" },
          },
        },
      },
    },
  },

  {
    "folke/snacks.nvim",
    keys = {
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
    },
    opts = function(_, opts)
      return U.extend_tbl(opts, {
        lazygit = {
          ---@type snacks.win.Config|{}
          win = {
            height = U.snacks.win.fullscreen_height,
            width = 0,
          },
        },
        gitbrowse = {
          open = U.open_in_browser,
        },
      } --[[@as snacks.Config]])
    end,
  },

  {
    "lewis6991/gitsigns.nvim",
    optional = true,
    opts = function(_, opts)
      opts.attach_to_untracked = true
      opts.gh = vim.fn.executable("gh") == 1

      local on_attach = opts.on_attach or function(_) end
      opts.on_attach = function(buffer)
        on_attach(buffer)

        ---@module 'gitsigns'
        local gs = package.loaded.gitsigns

        local function map(mode, l, r, desc)
          vim.keymap.set(mode, l, r, { buffer = buffer, desc = desc, silent = true })
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
        map("x", "gh", function()
          gs.stage_hunk({ vim.fn.line("."), vim.fn.line("v") })
          redraw()
        end, "Stage Hunk")
        map("o", "gh", "<cmd>Gitsigns select_hunk<CR>", "Hunk Textobj")
        map("n", "gH", gs.reset_hunk, "Reset Hunk")
        map("x", "gH", function()
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
        if not LazyVim.has("diffview.nvim") then
          map("n", "<leader>gD", function()
            gs.diffthis("~")
            if vim.g.user_close_key then
              map("n", vim.g.user_close_key, function()
                vim.keymap.del("n", vim.g.user_close_key, { buffer = buffer })
                vim.cmd.only()
              end, "Close Diff (Gitsigns)")
            end
          end, "Diff This ~")
        end
        map("n", "<leader>g?", gs.toggle_current_line_blame, "Toggle Blame Line (GitSigns)")
      end
    end,
  },
  {
    "nvim-mini/mini.diff",
    optional = true,
    opts = function()
      -- copied from: https://github.com/nvim-mini/mini.nvim/issues/1319#issuecomment-2761528147
      Snacks.util.set_hl({
        MiniDiffOverAdd = { bg = "#104010" }, -- regular green
        MiniDiffOverChange = { bg = "#600000" }, -- saturated red
        MiniDiffOverChangeBuf = { bg = "#006000" }, -- saturated green
        MiniDiffOverContext = { bg = "#401010" }, -- regular red
        MiniDiffOverContextBuf = "MiniDiffOverAdd",
        MiniDiffOverDelete = "MiniDiffOverContext",
      })

      -- HACK: redraw to update the signs for `gh`/`<leader>go`
      vim.api.nvim_create_autocmd("User", {
        pattern = "MiniDiffUpdated",
        callback = U.debounce_wrap(100, function()
          Snacks.util.redraw(vim.api.nvim_get_current_win())
        end),
      })
    end,
  },

  {
    "nvim-mini/mini-git",
    keys = {
      { "<leader>gc", "<Cmd>Git commit<CR>", desc = "Commit" },
      { "<leader>gC", "<Cmd>Git commit --amend<CR>", desc = "Commit Amend" },
      { "<leader>ga", "<Cmd>Git diff --cached<CR>", desc = "Diff Cached" },
      { "<leader>gA", "<Cmd>Git diff --cached -- %<CR>", desc = "Diff Cached Buffer" },
      { "<leader>gP", "<Cmd>Git push<CR>", desc = "Push" },
    },
    opts = function()
      vim.api.nvim_create_autocmd("User", {
        pattern = "MiniGitCommandSplit",
        callback = function(ev)
          if ev.data.git_subcommand == "diff" then
            vim.bo[ev.buf].modifiable = false
          end
        end,
      })

      -- fix `<cr>` for blink.cmp in `:Git commit`
      vim.api.nvim_create_autocmd("FileType", {
        pattern = "gitcommit",
        callback = function(ev)
          if vim.fn.fnamemodify(ev.file, ":t") ~= "COMMIT_EDITMSG" then
            return
          end
          vim.schedule(function()
            if vim.api.nvim_get_current_buf() == ev.buf then
              vim.bo[ev.buf].buflisted = true
            end
          end)
        end,
      })
    end,
    config = function(_, opts)
      require("mini.git").setup(opts)
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
}
