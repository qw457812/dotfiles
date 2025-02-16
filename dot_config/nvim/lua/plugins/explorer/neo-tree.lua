return {
  -- https://github.com/Matt-FTW/dotfiles/blob/main/.config/nvim/lua/plugins/extras/editor/neo-tree-extended.lua
  -- https://github.com/aimuzov/LazyVimx/blob/main/lua/lazyvimx/extras/ui/panels/explorer.lua
  -- https://github.com/rafi/vim-config/blob/master/lua/rafi/plugins/neo-tree.lua
  {
    "nvim-neo-tree/neo-tree.nvim",
    optional = true,
    dependencies = { "echasnovski/mini.icons" },
    keys = function(_, keys)
      local mappings = {
        {
          "<leader>fe",
          function()
            local command = require("neo-tree.command")

            -- https://github.com/AstroNvim/AstroNvim/blob/c7abf1c198f633574060807a181c6ce4d1c53a2c/lua/astronvim/plugins/neo-tree.lua#L14
            -- alternative: https://github.com/nvim-neo-tree/neo-tree.nvim/issues/872#issuecomment-1510551968
            if vim.bo.filetype == "neo-tree" then
              if vim.g.user_explorer_auto_close then
                command.execute({ action = "close" })
              else
                vim.cmd("wincmd p")
              end
              return
            end

            -- reveal the current file in root directory
            local function open()
              local root = LazyVim.root()
              local reveal_file = vim.fn.expand("%:p")
              if reveal_file == "" or not vim.uv.fs_stat(reveal_file) then
                reveal_file = vim.fn.getcwd()
              end
              command.execute({
                reveal_file = reveal_file, -- using `reveal_file` instead of `reveal` to reveal cwd for an unsaved file
                reveal_force_cwd = true,
                dir = vim.startswith(reveal_file, root) and root or nil, -- `dir = root` works too
              })
            end

            if U.toggle.zen:get() then
              U.toggle.zen:set(false)
              vim.schedule(open)
            else
              open()
            end
          end,
          desc = "Explorer NeoTree (Root Dir)",
        },
        -- stylua: ignore start
        { "<leader>fE", function() require("neo-tree.command").execute({ dir = vim.uv.cwd() }) end, desc = "Explorer NeoTree (cwd)" },
        -- { "<leader>ge", function() require("neo-tree.command").execute({ source = "git_status" }) end, desc = "Git Explorer" },
        -- { "<leader>be", function() require("neo-tree.command").execute({ source = "buffers" }) end, desc = "Buffer Explorer" },
        -- stylua: ignore end
        { "<leader>ge", false },
        { "<leader>be", false },
      }

      local opts = LazyVim.opts("neo-tree.nvim")
      if opts.filesystem.hijack_netrw_behavior ~= "disabled" then
        vim.list_extend(mappings, {
          { "-", "<leader>fe", desc = "Explorer NeoTree (Root Dir)", remap = true },
        })
      end
      return vim.list_extend(keys, mappings)
    end,
    opts = function(_, opts)
      local hijack_netrw = vim.g.user_hijack_netrw == "neo-tree.nvim"
      local last_root ---@type string?

      -- https://github.com/nvim-neo-tree/neo-tree.nvim/issues/639#issuecomment-1345617435
      local function is_visible()
        -- neo_tree_window_before_close event not triggered on `<C-w>o`
        if not vim.g.user_neotree_visible then
          return false
        end
        for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
          local buf = vim.api.nvim_win_get_buf(win)
          if vim.bo[buf].filetype == "neo-tree" then
            return true, buf, win
          end
        end
        vim.g.user_neotree_visible = false -- fix the case when neo-tree window is closed by `<C-w>o`
        return false
      end

      ---@param win? integer
      local function too_narrow(win)
        return vim.o.columns < 120 or vim.api.nvim_win_get_width(win or 0) < 120
      end

      vim.api.nvim_create_autocmd("WinResized", {
        group = vim.api.nvim_create_augroup("resize_neotree_auto_close", {}),
        callback = function(event)
          local win = event.match + 0
          if
            vim.g.user_explorer_auto_close
            or vim.api.nvim_win_get_config(win).relative ~= ""
            or not too_narrow(win)
            or vim.bo[vim.fn.winbufnr(win)].filetype == "neo-tree"
          then
            return
          end

          U.debounce("resize-neotree-auto-close", 50, function()
            if is_visible() then
              require("neo-tree.command").execute({ action = "close" })
            end
          end)
        end,
      })

      vim.api.nvim_create_autocmd("FileType", {
        pattern = "neo-tree-popup",
        callback = function(event)
          vim.defer_fn(function()
            for _, key in ipairs({ "h", "l", "/", "y" }) do
              vim.keymap.set("n", key, key, { buffer = event.buf })
            end
            vim.keymap.set("n", "<Esc>", U.keymap.clear_ui_esc, { buffer = event.buf })
          end, 100)
        end,
      })

      -- Fold {{{

      -- https://github.com/nvim-neo-tree/neo-tree.nvim/wiki/Recipes#emulating-vims-fold-commands
      -- TODO: https://github.com/nvim-neo-tree/neo-tree.nvim/discussions/368
      -- Expand a node and load filesystem info if needed.
      local function open_dir(state, dir_node)
        local fs = require("neo-tree.sources.filesystem")
        fs.toggle_directory(state, dir_node, nil, true, false)
      end

      -- Expand a node and all its children, optionally stopping at max_depth.
      local function recursive_open(state, node, max_depth)
        local max_depth_reached = 1
        local stack = { node }
        while next(stack) ~= nil do
          node = table.remove(stack)
          if node.type == "directory" and not node:is_expanded() then
            open_dir(state, node)
          end

          local depth = node:get_depth()
          max_depth_reached = math.max(depth, max_depth_reached)

          if not max_depth or depth < max_depth - 1 then
            local children = state.tree:get_nodes(node:get_id())
            for _, v in ipairs(children) do
              table.insert(stack, v)
            end
          end
        end

        return max_depth_reached
      end

      --- Open the fold under the cursor, recursing if count is given.
      local function neotree_zo(state, open_all)
        local node = state.tree:get_node()

        if open_all then
          recursive_open(state, node)
        else
          recursive_open(state, node, node:get_depth() + vim.v.count1)
        end

        require("neo-tree.ui.renderer").redraw(state)
      end

      --- Recursively open the current folder and all folders it contains.
      local function neotree_zO(state)
        neotree_zo(state, true)
      end

      -- The nodes inside the root folder are depth 2.
      local MIN_DEPTH = 2

      --- Close the node and its parents, optionally stopping at max_depth.
      local function recursive_close(state, node, max_depth)
        if max_depth == nil or max_depth <= MIN_DEPTH then
          max_depth = MIN_DEPTH
        end

        local last = node
        while node and node:get_depth() >= max_depth do
          if node:has_children() and node:is_expanded() then
            node:collapse()
          end
          last = node
          node = state.tree:get_node(node:get_parent_id())
        end

        return last
      end

      --- Close a folder, or a number of folders equal to count.
      local function neotree_zc(state, close_all)
        local node = state.tree:get_node()
        if not node then
          return
        end

        local max_depth
        if not close_all then
          max_depth = node:get_depth() - vim.v.count1
          if node:has_children() and node:is_expanded() then
            max_depth = max_depth + 1
          end
        end

        local renderer = require("neo-tree.ui.renderer")
        local last = recursive_close(state, node, max_depth)
        renderer.redraw(state)
        renderer.focus_node(state, last:get_id())
      end

      -- Close all containing folders back to the top level.
      local function neotree_zC(state)
        neotree_zc(state, true)
      end

      --- Open a closed folder or close an open one, with an optional count.
      local function neotree_za(state, toggle_all)
        local node = state.tree:get_node()
        if not node then
          return
        end

        if node.type == "directory" and not node:is_expanded() then
          neotree_zo(state, toggle_all)
        else
          neotree_zc(state, toggle_all)
        end
      end

      --- Recursively close an open folder or recursively open a closed folder.
      local function neotree_zA(state)
        neotree_za(state, true)
      end

      --- Set depthlevel, analagous to foldlevel, for the neo-tree file tree.
      local function set_depthlevel(state, depthlevel)
        if depthlevel < MIN_DEPTH then
          depthlevel = MIN_DEPTH
        end

        local stack = state.tree:get_nodes()
        while next(stack) ~= nil do
          local node = table.remove(stack)

          if node.type == "directory" then
            local should_be_open = depthlevel == nil or node:get_depth() < depthlevel
            if should_be_open and not node:is_expanded() then
              open_dir(state, node)
            elseif not should_be_open and node:is_expanded() then
              node:collapse()
            end
          end

          local children = state.tree:get_nodes(node:get_id())
          for _, v in ipairs(children) do
            table.insert(stack, v)
          end
        end

        vim.b.neotree_depthlevel = depthlevel
      end

      --- Refresh the tree UI after a change of depthlevel.
      -- @bool stay Keep the current node revealed and selected
      local function redraw_after_depthlevel_change(state, stay)
        local renderer = require("neo-tree.ui.renderer")
        local node = state.tree:get_node()

        if stay then
          renderer.expand_to_node(state.tree, node)
        else
          -- Find the closest parent that is still visible.
          local parent = state.tree:get_node(node:get_parent_id())
          while not parent:is_expanded() and parent:get_depth() > 1 do
            node = parent
            parent = state.tree:get_node(node:get_parent_id())
          end
        end

        renderer.redraw(state)
        renderer.focus_node(state, node:get_id())
      end

      --- Update all open/closed folders by depthlevel, then reveal current node.
      local function neotree_zx(state)
        set_depthlevel(state, vim.b.neotree_depthlevel or MIN_DEPTH)
        redraw_after_depthlevel_change(state, true)
      end

      --- Update all open/closed folders by depthlevel.
      local function neotree_zX(state)
        set_depthlevel(state, vim.b.neotree_depthlevel or MIN_DEPTH)
        redraw_after_depthlevel_change(state, false)
      end

      -- Collapse more folders: decrease depthlevel by 1 or count.
      local function neotree_zm(state)
        local depthlevel = vim.b.neotree_depthlevel or MIN_DEPTH
        set_depthlevel(state, depthlevel - vim.v.count1)
        redraw_after_depthlevel_change(state, false)
      end

      -- Collapse all folders. Set depthlevel to MIN_DEPTH.
      local function neotree_zM(state)
        set_depthlevel(state, MIN_DEPTH)
        redraw_after_depthlevel_change(state, false)
      end

      -- Expand more folders: increase depthlevel by 1 or count.
      local function neotree_zr(state)
        local depthlevel = vim.b.neotree_depthlevel or MIN_DEPTH
        set_depthlevel(state, depthlevel + vim.v.count1)
        redraw_after_depthlevel_change(state, false)
      end

      -- Expand all folders. Set depthlevel to the deepest node level.
      local function neotree_zR(state)
        local top_level_nodes = state.tree:get_nodes()

        local max_depth = 1
        for _, node in ipairs(top_level_nodes) do
          max_depth = math.max(max_depth, recursive_open(state, node))
        end

        vim.b.neotree_depthlevel = max_depth
        redraw_after_depthlevel_change(state, false)
      end

      -- }}}

      return vim.tbl_deep_extend("force", opts, {
        sources = { "filesystem" },
        -- close_if_last_window = true, -- disabled as it causes `:bd` to exit vim in java library buffer when neo-tree opened, see #241
        default_component_configs = {
          -- use mini.icons instead of nvim-web-devicons
          -- https://github.com/nvim-neo-tree/neo-tree.nvim/pull/1527#issuecomment-2233186777
          icon = {
            provider = function(icon, node)
              if node.type == "file" or node.type == "directory" then
                local text, hl = require("mini.icons").get(node.type, node.name)
                icon.highlight = hl
                -- for directory, only set the icon text if it is not expanded
                if node.type == "file" or not node:is_expanded() then
                  icon.text = text
                end
              end
            end,
          },
          kind_icon = {
            provider = function(icon, node)
              icon.text, icon.highlight = require("mini.icons").get("lsp", node.extra.kind.name)
            end,
          },
          -- annoying when `toggle_auto_expand_width`
          file_size = { enabled = false },
          type = { enabled = false },
          last_modified = { enabled = false },
        },
        commands = {
          unfocus_window = function(state)
            local win = vim.api.nvim_get_current_win()
            vim.cmd.wincmd("p")
            if win == vim.api.nvim_get_current_win() then
              if state.current_position == "left" then
                vim.cmd.wincmd("l")
              end
            end
          end,
          close_or_unfocus = function(state)
            if vim.g.user_explorer_auto_close then
              state.commands["close_window"](state)
            else
              state.commands["unfocus_window"](state)
              if too_narrow() then
                state.commands["close_window"](state)
              end
            end
          end,
          cancel_or_close_or_unfocus = function(state)
            local preview = require("neo-tree.sources.common.preview")
            -- copied from: https://github.com/nvim-neo-tree/neo-tree.nvim/blob/206241e451c12f78969ff5ae53af45616ffc9b72/lua/neo-tree/sources/common/commands.lua#L653
            local has_preview = preview.is_active()
            local has_floating = state.current_position == "float"
            local has_filter = state.name == "filesystem" and state.search_pattern ~= nil
            if has_preview or has_floating or has_filter then
              -- original behavior of <esc> is `cancel`: close preview or floating neo-tree window
              -- require("neo-tree.sources.common.commands").cancel(state)
              if has_preview then
                preview.hide()
              end
              if has_floating then
                require("neo-tree.ui.renderer").close_all_floating_windows()
              end
              if has_filter then
                require("neo-tree.sources.filesystem.commands").clear_filter(state)
              end
            else
              -- close_or_unfocus if nothing to do
              -- like Lazygit's `quitOnTopLevelReturn`: https://github.com/jesseduffield/lazygit/blob/753b16b6970dbfcbe2c4349bbcdea85587ea51f7/docs/Config.md?plain=1#L386
              state.commands["close_or_unfocus"](state)
            end
          end,
          -- https://github.com/AstroNvim/AstroNvim/blob/c7abf1c198f633574060807a181c6ce4d1c53a2c/lua/astronvim/plugins/neo-tree.lua#L113
          parent_or_close = function(state)
            local node = state.tree:get_node()
            if node:has_children() and node:is_expanded() then
              state.commands.toggle_node(state)
            else
              require("neo-tree.ui.renderer").focus_node(state, node:get_parent_id())
            end
          end,
          child_or_open = function(state)
            local node = state.tree:get_node()
            if node:has_children() then
              if not node:is_expanded() then -- if unexpanded, expand
                state.commands.toggle_node(state)
              else -- if expanded and has children, seleect the next child
                if node.type == "file" then
                  state.commands.open(state)
                else
                  require("neo-tree.ui.renderer").focus_node(state, node:get_child_ids()[1])
                end
              end
            else -- if has no children
              state.commands.open(state)
            end
          end,
          copy_selector = function(state)
            local node = state.tree:get_node()
            local filepath = node:get_id()
            local filename = node.name
            local modify = vim.fn.fnamemodify

            local vals = {
              ["BASENAME"] = modify(filename, ":r"),
              ["EXTENSION"] = modify(filename, ":e"),
              ["FILENAME"] = filename,
              ["PATH (CWD)"] = modify(filepath, ":."),
              ["PATH (HOME)"] = modify(filepath, ":~"),
              ["PATH"] = filepath,
              ["URI"] = vim.uri_from_fname(filepath),
            }

            local options = vim.tbl_filter(function(val)
              return vals[val] ~= ""
            end, vim.tbl_keys(vals))
            if vim.tbl_isempty(options) then
              LazyVim.warn("No values to copy", { title = "Neo-tree" })
              return
            end
            table.sort(options)
            vim.ui.select(options, {
              prompt = "Choose to copy to clipboard:",
              format_item = function(item)
                return ("%s: %s"):format(item, vals[item])
              end,
            }, function(choice)
              local result = vals[choice]
              if result then
                LazyVim.info(("Copied: `%s`"):format(result), { title = "Neo-tree" })
                vim.fn.setreg(vim.v.register, result)
              end
            end)
          end,
          -- alternative: https://github.com/nvim-neo-tree/neo-tree.nvim/wiki/Recipes#find-with-telescope
          find_in_dir = function(state)
            local node = state.tree:get_node()
            local path = node.type == "file" and node:get_parent_id() or node:get_id()
            Snacks.picker.files({ cwd = path, hidden = true, ignored = true, follow = true })
          end,
          grep_in_dir = function(state)
            local node = state.tree:get_node()
            local path = node.type == "file" and node:get_parent_id() or node:get_id()
            LazyVim.pick("live_grep", { cwd = path })()
          end,
          grug_far = function(state)
            local node = state.tree:get_node()
            local path = node.type == "directory" and vim.fn.fnameescape(vim.fn.fnamemodify(node:get_id(), ":p"))
              or vim.fn.fnameescape(vim.fn.fnamemodify(node:get_id(), ":h"))
            if vim.g.user_explorer_auto_close then
              state.commands.close_window(state)
            end
            U.explorer.grug_far(path)
          end,
          -- https://github.com/nvim-neo-tree/neo-tree.nvim/blob/fbb631e818f48591d0c3a590817003d36d0de691/doc/neo-tree.txt#L535
          grug_far_visual = function(state, selected_nodes, callback)
            local paths = {}
            for _, node in ipairs(selected_nodes) do
              local path = node.type == "directory" and vim.fn.fnameescape(vim.fn.fnamemodify(node:get_id(), ":p"))
                or vim.fn.fnameescape(vim.fn.fnamemodify(node:get_id(), ":h"))
              U.list_insert_unique(paths, path)
            end
            if vim.g.user_explorer_auto_close then
              state.commands.close_window(state)
            end
            U.explorer.grug_far(table.concat(paths, " "))
          end,
        },
        window = {
          width = math.max(35, math.min(50, math.floor(vim.o.columns * 0.25))),
          mappings = {
            -- ["-"] = "close_or_unfocus", -- toggle neo-tree, work with `-` defined in `keys` above
            ["-"] = hijack_netrw and "close_or_unfocus" or {
              function(state)
                local node = state.tree:get_node()
                local path = node.type == "file" and node:get_parent_id() or node:get_id()
                vim.cmd.edit(path)
              end,
              desc = "Open with default explorer",
            },
            ["<esc>"] = {
              "cancel_or_close_or_unfocus",
              desc = "cancel / close_or_unfocus",
            },
            ["h"] = "parent_or_close",
            ["l"] = "child_or_open",
            ["<leader>fy"] = {
              function(state)
                local node = state.tree:get_node()
                local path = node:get_id()
                vim.fn.setreg(vim.v.register, U.path.home_to_tilde(path), "c")
              end,
              desc = "Copy Path to Clipboard",
            },
            ["<leader>fY"] = "copy_selector",
            ["<leader><space>"] = "find_in_dir",
            ["<leader>/"] = "grep_in_dir",
            ["<c-space>"] = {
              function(state)
                local node = state.tree:get_node()
                local path = node.type == "file" and node:get_parent_id() or node:get_id()
                Snacks.terminal(nil, { cwd = path })
              end,
              desc = "Terminal (NeoTree Dir)",
            },
            -- ["d"] = "none",
            -- ["dd"] = "delete",
            -- ["y"] = "none",
            -- ["yy"] = "copy_to_clipboard",
            ["<leader>sr"] = "grug_far",
          },
        },
        filesystem = {
          filtered_items = {
            hide_dotfiles = false,
            hide_gitignored = false,
            hide_hidden = false,
            hide_by_name = {
              -- "node_modules",
              -- ".git",
            },
            never_show = {
              ".DS_Store",
              "thumbs.db",
            },
          },
          -- whether to use for editing directories (e.g. `vim .` or `:e src/`)
          -- possible values: "open_default" (default), "open_current", "disabled"
          hijack_netrw_behavior = hijack_netrw and "open_default" or "disabled",
          follow_current_file = { enabled = false }, -- see vim_buffer_enter event below
          -- commands = {},
          window = {
            -- TODO: unify the keybindings of yazi and neo-tree.nvim
            mappings = {
              -- ["<esc>"] = {
              --   function(state)
              --     require("neo-tree.sources.common.commands").cancel(state) -- close preview or floating neo-tree window
              --     require("neo-tree.sources.filesystem.commands").clear_filter(state)
              --   end,
              --   desc = "cancel + clear_filter",
              -- },
              ["<esc>"] = {
                "cancel_or_close_or_unfocus",
                desc = "(cancel + clear_filter) / close_or_unfocus",
              },
              -- https://github.com/nvim-neo-tree/neo-tree.nvim/wiki/Tips#navigation-with-hjkl
              ["h"] = {
                function(state)
                  local node = state.tree:get_node()
                  if node.type == "directory" and node:is_expanded() and node:has_children() then
                    require("neo-tree.sources.filesystem").toggle_directory(state, node)
                  elseif node:get_depth() == 1 then
                    require("neo-tree.sources.filesystem.commands").navigate_up(state)
                  else
                    require("neo-tree.ui.renderer").focus_node(state, node:get_parent_id())
                  end
                end,
                desc = "focus parent / close_node / navigate_up",
              },
              ["l"] = {
                function(state)
                  local node = state.tree:get_node()
                  if node.type == "directory" then
                    if not node:is_expanded() then
                      require("neo-tree.sources.filesystem").toggle_directory(state, node)
                    elseif node:has_children() then
                      require("neo-tree.ui.renderer").focus_node(state, node:get_child_ids()[1])
                    end
                  else
                    require("neo-tree.sources.filesystem.commands").open(state)
                  end
                end,
                desc = "expand node / focus first child / open",
              },
              ["<cr>"] = { -- <tab> is mapped to <C-w>w
                function(state)
                  local node = state.tree:get_node()
                  if require("neo-tree.utils").is_expandable(node) then
                    state.commands["toggle_node"](state)
                  else
                    state.commands["open"](state)
                    vim.cmd("Neotree reveal")
                  end
                end,
                desc = "Open without focus",
              },
              ["i"] = "none",
              ["gk"] = "show_file_details",
              ["H"] = "none",
              ["g."] = "toggle_hidden", -- TODO: not working
              ["[g"] = "none",
              ["]g"] = "none",
              ["[h"] = "prev_git_modified",
              ["]h"] = "next_git_modified",
              ["z"] = "none",
              -- https://github.com/folke/trouble.nvim/blob/254145ffd528b98eb20be894338e2d5c93fa02c2/README.md?plain=1#L184
              ["zo"] = { neotree_zo, desc = "fold_open" },
              ["zO"] = { neotree_zO, desc = "fold_open_recursive" },
              ["zc"] = { neotree_zc, desc = "fold_close" },
              ["zC"] = { neotree_zC, desc = "fold_close_recursive" },
              ["za"] = { neotree_za, desc = "fold_toggle" },
              ["zA"] = { neotree_zA, desc = "fold_toggle_recursive" },
              ["zx"] = { neotree_zx, desc = "fold_update" },
              ["zX"] = { neotree_zX, desc = "fold_update_all" },
              ["zm"] = { neotree_zm, desc = "fold_more" },
              ["zM"] = { neotree_zM, desc = "fold_close_all" },
              ["zr"] = { neotree_zr, desc = "fold_reduce" },
              ["zR"] = { neotree_zR, desc = "fold_open_all" },
            },
            fuzzy_finder_mappings = {
              ["<C-j>"] = "move_cursor_down",
              ["<C-k>"] = "move_cursor_up",
              ["<esc>"] = function()
                vim.cmd.stopinsert()
              end,
            },
          },
        },
        -- buffers = {
        --   window = {
        --     mappings = {
        --       ["bd"] = "none", -- use `dd` instead
        --       ["dd"] = "buffer_delete",
        --     },
        --   },
        -- },
        event_handlers = {
          -- https://github.com/nvim-neo-tree/neo-tree.nvim/wiki/Recipes#auto-close-on-open-file
          -- alternative: https://github.com/nvim-neo-tree/neo-tree.nvim/issues/344
          {
            event = "file_opened",
            handler = function()
              if vim.g.user_explorer_auto_close or too_narrow() then
                require("neo-tree.command").execute({ action = "close" })
              end
            end,
          },
          {
            event = "neo_tree_popup_input_ready",
            ---@param args { bufnr: integer, winid: integer }
            handler = function(args)
              -- map <esc> to enter normal mode of NuiInput (by default closes prompt)
              vim.keymap.set("i", "<esc>", vim.cmd.stopinsert, { noremap = true, buffer = args.bufnr })
            end,
          },
          {
            event = "neo_tree_window_after_open",
            handler = function(args)
              if args.position == "left" then
                vim.cmd("wincmd =")
              end
            end,
          },
          {
            event = "neo_tree_window_after_close",
            handler = function(args)
              if args.position == "left" then
                vim.cmd("wincmd =")
              end
            end,
          },
          {
            event = "neo_tree_window_after_open",
            handler = function()
              vim.g.user_neotree_visible = true
            end,
          },
          {
            event = "neo_tree_window_before_close",
            handler = function()
              vim.g.user_neotree_visible = false
            end,
          },
          -- enhance follow_current_file to adapt to root changes
          -- see: https://github.com/nvim-neo-tree/neo-tree.nvim/blob/e6645ecfcba3e064446a6def1c10d788c9873f51/lua/neo-tree/sources/filesystem/init.lua#L378
          {
            event = "vim_buffer_enter",
            ---@param args { afile: string }
            handler = function(args)
              local utils = require("neo-tree.utils")
              if vim.g.user_explorer_auto_close or not utils.is_real_file(args.afile) or utils.is_floating() then
                last_root = nil
                return
              end

              U.debounce("neo-tree-follow-root", 100, function()
                -- call is_visible() first to fix vim.g.user_neotree_visible
                if not is_visible() or vim.fn.bufnr(args.afile) ~= vim.api.nvim_get_current_buf() then
                  last_root = nil
                  return
                end
                local root = LazyVim.root({ normalize = true })
                if root ~= last_root then
                  if utils.is_subpath(root, vim.uv.fs_realpath(args.afile) or args.afile) then
                    -- root changed, navigate to the new root first
                    require("neo-tree.command").execute({ action = "show", dir = root })
                    last_root = root
                  else
                    last_root = nil
                  end
                end
                require("neo-tree.sources.filesystem").follow()
              end)
            end,
          },
        },
      })
    end,
  },

  {
    "folke/edgy.nvim",
    optional = true,
    opts = function(_, opts)
      for _, view in ipairs(opts.left or {}) do
        if view.ft == "neo-tree" then
          local window = LazyVim.opts("neo-tree.nvim").window or {}
          -- :=require("neo-tree.defaults").window.width
          view.size = { width = window.width or 40 }
          view.title = "Neo-Tree"
          break
        end
      end
    end,
  },

  {
    "akinsho/bufferline.nvim",
    optional = true,
    opts = {
      options = {
        offsets = {
          {
            filetype = "neo-tree",
            text = function()
              local cwd = LazyVim.root.cwd()
              local root = LazyVim.root.get({ normalize = true })
              return cwd == root and " Explorer" or " 󱞊 " .. U.path.home_to_tilde(cwd)
            end,
            highlight = "NeoTreeRootName", -- Directory
            text_align = "left",
          },
        },
      },
    },
  },
}
