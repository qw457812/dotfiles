---@type LazySpec
return {
  {
    "LazyVim/LazyVim",
    opts = function()
      local commit_ft = { "gitcommit", "gitrebase", "svn" }
      local commit_filename = { "COMMIT_EDITMSG", "git-rebase-todo", "svn-commit.tmp" }
      vim.api.nvim_create_autocmd("FileType", {
        pattern = commit_ft,
        callback = function(ev)
          if not vim.list_contains(commit_filename, vim.fn.fnamemodify(ev.file, ":t")) then
            return
          end
          local win = vim.fn.bufwinid(ev.buf)
          vim.defer_fn(function()
            if vim.api.nvim_get_current_buf() == ev.buf and vim.api.nvim_get_current_win() == win then
              vim.api.nvim_win_set_cursor(win, { 1, 0 })
              if vim.api.nvim_get_current_line():match("^%s*$") then
                vim.cmd("startinsert")
              end
            end
          end, 50)

          -- Abort commit for `git commit --amend`
          vim.keymap.set("n", "<C-c>", function()
            Snacks.picker.util.confirm("Abort Commit?", function()
              -- aborting commit due to empty commit message
              vim.api.nvim_buf_set_lines(ev.buf, 0, -1, false, {})
              vim.cmd.write()
            end)
          end, { buffer = ev.buf, desc = "Abort Commit" })
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
      if LazyVim.pick.picker.name ~= "snacks" then
        return keys
      end

      ---use `opts.staged = true` instead of `opts.cmd_args = { "--staged" }` or `opts.cmd_args = { "--cached" }`
      ---see: https://github.com/folke/snacks.nvim/blob/1fb3f4de49962a80cb88a9b143bc165042c72165/lua/snacks/picker/source/git.lua#L277-L292
      ---@param opts? snacks.picker.git.diff.Config
      ---@return snacks.Picker
      local function git_diff_pick(opts)
        ---@type snacks.picker.git.diff.Config
        opts = vim.tbl_deep_extend("force", {
          cwd = LazyVim.root.git(),
          cmd_args = {},
        } --[[@as snacks.picker.git.diff.Config]], opts or {})

        if opts.staged == nil or opts.base then
          opts = vim.tbl_deep_extend("force", {
            win = {
              input = { keys = { ["<Space>"] = false } },
              list = { keys = { ["<Space>"] = false } },
            },
          }, opts)
        end

        local path = vim.api.nvim_buf_get_name(0)
        local picker = Snacks.picker.git_diff(opts)
        -- focus the hunk at the cursor file
        picker.matcher.task:on(
          "done",
          vim.schedule_wrap(function()
            -- ref: https://github.com/folke/snacks.nvim/blob/ca0f8b2c09a6b437479e7d12bdb209731d9eb621/lua/snacks/picker/config/sources.lua#L236-L242
            for i, item in ipairs(picker:items()) do
              if Snacks.picker.util.path(item) == path then
                picker.list:view(i)
                Snacks.picker.actions.list_scroll_center(picker)
                break
              end
            end
          end)
        )
        return picker
      end

      -- stylua: ignore
      return vim.list_extend(keys, {
        -- { "<leader>gd", function() git_diff_pick() end, desc = "Git Diff HEAD (hunks)" },
        { "<leader>gd", function() git_diff_pick({ staged = false }) end, desc = "Git Diff (hunks)" },
        -- { "<leader>gD", function() git_diff_pick({ staged = false, cmd_args = { "--", vim.api.nvim_buf_get_name(0) } }) end, desc = "Git Diff Buffer (hunks)" },
        { "<leader>gD", function() git_diff_pick({ base = "origin", group = true }) end, desc = "Git Diff (origin)" },
        { "<leader>ga", function() git_diff_pick({ staged = true }) end, desc = "Git Diff Staged (hunks)" },
        -- {
        --   "<leader>gA",
        --   function() git_diff_pick({ staged = true, cmd_args = { "--", vim.api.nvim_buf_get_name(0) } }) end,
        --   desc = "Git Diff Staged Buffer (hunks)",
        -- },
        -- { "<leader>ga", function() U.git.diff_term({ staged = true }) end, desc = "Git Diff Staged" },
        -- {
        --   "<leader>gA",
        --   function()
        --     U.git.diff_term({
        --       staged = true,
        --       args = { "-c", "delta.file-style=omit" },
        --       cmd_args = { "--", vim.api.nvim_buf_get_name(0) },
        --     })
        --   end,
        --   desc = "Git Diff Staged Buffer",
        -- },
        { "<leader>gA", function() U.git.diff_term({ staged = true, ignore_space = true }) end, desc = "Git Diff Staged (ignore space)" },
        { "<leader>gs", function() Snacks.picker.git_status({ cwd = LazyVim.root.git() }) end, desc = "Git Status" },
        { "<leader>gS", function() Snacks.picker.git_stash({ cwd = LazyVim.root.git() }) end, desc = "Git Stash" },
        { "<leader>gb", function() Snacks.picker.git_branches({ cwd = LazyVim.root.git() }) end, desc = "Git Branches" },
        { "<leader>gB", function() Snacks.picker.git_log_line() end, desc = "Git Blame Line" },
      })
    end,
    ---@module "snacks"
    ---@type snacks.Config
    opts = {
      picker = {
        sources = {
          git_branches = {
            all = true,
          },
          git_diff = {
            actions = {
              -- https://github.com/folke/snacks.nvim/blob/1fb3f4de49962a80cb88a9b143bc165042c72165/lua/snacks/picker/actions.lua#L343-L363
              -- https://github.com/chrisgrieser/.config/blob/fd27c6f94b748f436fa6251006fcd5641f9eeac6/nvim/lua/plugin-specs/snacks/snacks-picker.lua#L200-L215
              -- https://github.com/nvim-mini/mini.diff/blob/98fc732d5835eb7b6539f43534399b07b17f4e28/lua/mini/diff.lua#L1818-L1831
              git_apply = function(picker)
                local items = picker:selected({ fallback = true })
                if #items == 0 then
                  return
                end

                local is_staged = items[1].staged
                local cmd = { "git", "apply", "--cached", is_staged and "--reverse" or nil }
                local diffs = vim.tbl_map(function(item)
                  assert(item.diff and item.staged ~= nil, "Can't stage/unstage this change") -- see: https://github.com/folke/snacks.nvim/commit/9cde35b7b16244fee5c6f73749523e95e4a2b432
                  assert(item.staged == is_staged, "Cannot apply mixed staged/unstaged hunks") -- TODO: mixed staged/unstaged
                  return item.diff
                end, items)
                -- alternative: vim.system()
                Snacks.picker.util.cmd(cmd, function()
                  picker:refresh()
                end, { cwd = items[1].cwd, input = table.concat(diffs, "\n") })
              end,
            },
            win = {
              input = {
                keys = {
                  ["<Tab>"] = { "select_and_next", mode = { "i", "n" } },
                  ["<Space>"] = "git_apply", -- gh
                },
              },
              list = {
                keys = {
                  ["<Space>"] = "git_apply",
                },
              },
            },
          },
          git_status = {
            win = {
              input = {
                keys = {
                  ["<Tab>"] = { "select_and_next", mode = { "i", "n" } },
                  ["<Space>"] = "git_stage",
                },
              },
              list = {
                keys = {
                  ["<Space>"] = "git_stage",
                },
              },
            },
          },
        },
      },
    },
  },

  -- diff previewer
  {
    "folke/snacks.nvim",
    ---@param opts snacks.Config
    opts = function(_, opts)
      ---@param args? string[] { "--file-style", "omit", "--hunk-header-style", "omit" }
      ---@return string[]
      local function diff_cmd(args)
        local cmd = vim.list_extend({ "delta" }, vim.g.user_is_termux and {} or { "--line-numbers" })
        return vim.list_extend(cmd, args or {})
      end

      ---@param args? string[] { "-c", "delta.file-style=omit", "-c", "delta.hunk-header-style=omit" }
      ---@return string[]
      local function git_args(args)
        return vim.list_extend(vim.g.user_is_termux and {} or { "-c", "delta.line-numbers=true" }, args or {})
      end

      ---@return string
      local function layout_preset()
        local layouts = { "diff", "borderless_diff", "based_borderless_diff" }
        return layouts[math.random(#layouts)]
      end

      return U.extend_tbl(opts, {
        picker = {
          layouts = {
            -- based on the narrow preset, with fullscreen and bigger preview
            diff = {
              layout = {
                backdrop = false,
                width = 0,
                height = U.snacks.win.fullscreen_height,
                border = "none",
                box = "vertical",
                { win = "preview", title = "{preview}", height = 0.75, border = "rounded" },
                {
                  box = "vertical",
                  border = "rounded",
                  title = "{title} {live} {flags}",
                  title_pos = "center",
                  { win = "input", height = 1, border = "bottom" },
                  { win = "list", border = "none" },
                },
              },
            },
            borderless_diff = {
              layout = {
                backdrop = false,
                width = 0,
                height = U.snacks.win.fullscreen_height,
                border = "none",
                box = "vertical",
                { win = "preview", title = "{preview}", height = 0.75, border = "solid" },
                {
                  box = "vertical",
                  border = "solid",
                  title = "{title} {live} {flags}",
                  title_pos = "center",
                  { win = "input", height = 1, border = { "", "", "", "", "", " ", "", "" } },
                  { win = "list", border = "none" },
                },
              },
            },
            based_borderless_diff = {
              layout = {
                backdrop = false,
                width = 0,
                height = U.snacks.win.fullscreen_height,
                border = "none",
                box = "vertical",
                { win = "preview", title = "{preview}", height = 0.75, border = "solid" },
                {
                  box = "vertical",
                  border = { " ", "─", " ", " ", " ", " ", " ", " " },
                  title = "{title} {live} {flags}",
                  title_pos = "center",
                  { win = "input", height = 1, border = "bottom" },
                  { win = "list", border = "none" },
                },
              },
            },
          },
          previewers = {
            diff = {
              style = "terminal",
              cmd = diff_cmd(),
            },
            git = {
              args = git_args(),
            },
          },
          sources = {
            undo = {
              layout = { preset = layout_preset },
              -- overwrite `opts.picker.previewers.diff.cmd`
              previewers = { diff = { cmd = diff_cmd({ "--file-style", "omit" }) } },
            },
            git_diff = {
              layout = { preset = layout_preset },
              previewers = {
                diff = {
                  cmd = vim.g.user_is_termux and diff_cmd({ "--hunk-header-style", "omit" }) or nil,
                },
              },
            },
            git_status = {
              layout = { preset = layout_preset },
            },
            git_stash = {
              layout = { preset = layout_preset },
            },
            git_log = {
              layout = { preset = layout_preset },
            },
            git_log_file = {
              layout = { preset = layout_preset },
              -- overwrite `opts.picker.previewers.git.args`
              previewers = { git = { args = git_args({ "-c", "delta.file-style=omit" }) } },
            },
            git_log_line = {
              layout = { preset = layout_preset },
              previewers = { git = { args = git_args({ "-c", "delta.file-style=omit" }) } },
            },
            gh_diff = {
              layout = { preset = layout_preset },
            },
          },
        },
      } --[[@as snacks.Config]])
    end,
  },

  -- gh
  {
    "folke/snacks.nvim",
    keys = function(_, keys)
      if LazyVim.pick.picker.name ~= "snacks" then
        return keys
      end

      -- ref: https://github.com/folke/snacks.nvim/blob/50436373c277906cf40e47380f3dc1bd7769a885/lua/snacks/gh/api.lua#L464-L495
      ---@param cwd? string
      ---@return string?
      local function repo(cwd)
        if vim.b.snacks_gh and not cwd then
          return vim.b.snacks_gh.repo
        end

        local git_root = Snacks.git.get_root(cwd)
        if not git_root then
          return
        end

        local git_config = vim.fn
          .system({ "git", "-C", git_root, "config", "--get-regexp", "^remote\\.(upstream|origin)\\.url" })
          :gsub("\n$", "")

        local cfg = {} ---@type table<string, string>
        for _, line in ipairs(vim.split(git_config, "\n")) do
          local key, value = line:match("^([^%s]+)%s+(.+)$")
          if key then
            cfg[key] = value
          end
        end

        ---@param u? string
        ---@return string?
        local function parse(u)
          return u and (u:match("github%.com[:/](.+/.+)%.git") or u:match("github%.com[:/](.+/.+)$")) or nil
        end

        return parse(cfg["remote.upstream.url"]) or parse(cfg["remote.origin.url"])
      end

      -- stylua: ignore
      return vim.list_extend(keys, {
        { "<leader>gi", function() Snacks.picker.gh_issue({ repo = repo() }) end, desc = "GitHub Issues (open)" },
        { "<leader>gI", function() Snacks.picker.gh_issue({ repo = repo(), state = "all" }) end, desc = "GitHub Issues (all)" },
        { "<leader>gp", function() Snacks.picker.gh_pr({ repo = repo() }) end, desc = "GitHub Pull Requests (open)" },
        { "<leader>gP", function() Snacks.picker.gh_pr({ repo = repo(), state = "all" }) end, desc = "GitHub Pull Requests (all)" },
      })
    end,
    ---@module "snacks"
    ---@type snacks.Config
    opts = {
      picker = {
        sources = {
          gh_issue = {
            win = {
              input = {
                keys = {
                  ["<localleader>o"] = "gh_open",
                  ["<localleader>y"] = "gh_yank",
                  ["<localleader>b"] = "gh_browse",
                },
              },
              list = {
                keys = {
                  ["y"] = false,
                  ["<localleader>y"] = { "gh_yank", mode = { "n", "x" } },
                },
              },
            },
          },
          gh_pr = {
            win = {
              input = {
                keys = {
                  ["<localleader>o"] = "gh_open",
                  ["<localleader>y"] = "gh_yank",
                  ["<localleader>b"] = "gh_browse",
                  ["<localleader>d"] = "gh_diff",
                },
              },
              list = {
                keys = {
                  ["y"] = false,
                  ["<localleader>y"] = { "gh_yank", mode = { "n", "x" } },
                },
              },
            },
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
          -- config = {
          --   os = {
          --     -- ref: https://github.com/jesseduffield/lazygit/blob/e6bd9d0ae6dd30d04dfe77d2cac15ac54fa18ff6/pkg/config/editor_presets.go#L60
          --     edit = vim.o.shell:find("fish")
          --         and 'begin; if test -z "$NVIM"; nvim -- {{filename}}; else; nvim --server "$NVIM" --remote-send "q"; and nvim --server "$NVIM" --remote {{filename}}; end; end'
          --       or nil,
          --   },
          -- },
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
        -- map("n", "<leader>gD", function()
        --   gs.diffthis("~")
        --   if vim.g.user_close_key then
        --     map("n", vim.g.user_close_key, function()
        --       vim.keymap.del("n", vim.g.user_close_key, { buffer = buffer })
        --       vim.cmd.only()
        --     end, "Close Diff (Gitsigns)")
        --   end
        -- end, "Diff This ~")
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
    keys = function()
      ---@param amend? boolean
      local function commit(amend)
        return function()
          U.git.diff_term({
            staged = true,
            -- ignore_space = true,
            on_diff = vim.schedule_wrap(function(has_diff)
              if has_diff or amend then
                vim.cmd("Git commit" .. (amend and " --amend" or ""))

                -- HACK: sometimes the gitcommit buffer is opened but not focused
                if vim.bo.filetype ~= "gitcommit" then
                  LazyVim.warn("Focusing gitcommit buffer", { title = "Git Commit" })
                  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
                    if vim.bo[buf].filetype == "gitcommit" then
                      vim.api.nvim_set_current_buf(buf)
                      vim.api.nvim_win_set_cursor(0, { 1, 0 })
                      if vim.api.nvim_get_current_line():match("^%s*$") then
                        vim.cmd("startinsert")
                      end
                      break
                    end
                  end
                end
              end
            end),
          })
        end
      end

      return {
        { "<leader>gc", commit(), desc = "Commit" },
        { "<leader>gC", commit(true), desc = "Commit Amend" },
        -- { "<leader>ga", "<Cmd>Git diff --cached<CR>", desc = "Diff Staged" },
        -- { "<leader>gA", "<Cmd>Git diff --cached -- %<CR>", desc = "Diff Staged Buffer" },
        -- { "<leader>gP", "<Cmd>Git push<CR>", desc = "Push" },
      }
    end,
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
            if vim.api.nvim_buf_is_valid(ev.buf) then
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
      -- { "<leader>gD", "<cmd>DiffviewFileHistory<CR>", desc = "Diff Repo (Diff View)" },
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
