if not vim.g.vscode then
  return {}
end

local vscode = require("vscode")
local is_cursor = vscode.eval('return vscode.env.appName.includes("Cursor")')
local map = U.keymap.map

vim.notify = vscode.notify
-- vim.g.clipboard = vim.g.vscode_clipboard

---@param mode string|string[]
---@param key string|string[]
---@param command string|string[]
---@param opts? vim.keymap.set.Opts
local function vscode_map(mode, key, command, opts)
  command = type(command) == "string" and { command } or command
  ---@cast command string[]

  -- https://github.com/vscode-neovim/vscode-neovim#%EF%B8%8F-api
  local execute = #command == 1 and vscode.action or vscode.call

  map(mode, key, function()
    for _, c in ipairs(command) do
      execute(c)
    end
  end, opts)
end

---@module "lazy"
---@type LazySpec
return {
  {
    "snacks.nvim",
    ---@module "snacks"
    ---@param opts snacks.Config
    config = function(_, opts)
      require("snacks").setup(vim.tbl_deep_extend("force", opts, {
        bigfile = { enabled = false },
        dashboard = { enabled = false },
        indent = { enabled = false },
        input = { enabled = false },
        notifier = { enabled = false },
        picker = { enabled = false },
        quickfile = { enabled = false },
        scroll = { enabled = false },
        statuscolumn = { enabled = false },
        image = { enabled = false },
        scope = { enabled = false },
        words = { enabled = false },
      } --[[@as snacks.Config]]))
    end,
  },
  {
    "LazyVim/LazyVim",
    opts = function()
      vim.api.nvim_create_autocmd("BufEnter", {
        callback = function()
          vim.defer_fn(function()
            local mode = vim.fn.mode(true)
            if mode == "v" or mode == "V" or mode == "\22" then
              -- fix: start visual mode after editor.action.goToReferences
              -- TODO: editor.action.goToReferences jumps to the same file
              vim.api.nvim_feedkeys(vim.keycode("<esc>"), "n", false)
            elseif mode == "i" then
              vim.cmd("stopinsert")
            end
          end, 100)
        end,
      })

      vim.api.nvim_create_autocmd("User", {
        pattern = "LazyVimKeymaps",
        once = true,
        callback = function()
          -- vscode_map("n", "u", "undo", { desc = "VSCode Undo" })
          -- vscode_map("n", "U", "redo", { desc = "VSCode Redo" })
          map("n", "u", "u", { desc = "Undo" })
          map("n", "U", "<C-r>", { desc = "Redo" })

          vscode_map("n", "<Left>", "workbench.action.navigateBack", { desc = "Go Back" })
          vscode_map("n", "<Right>", "workbench.action.navigateForward", { desc = "Go Forward" })

          vscode_map("n", { "<Up>", "K", "[b" }, "workbench.action.previousEditor", { desc = "Prev Editor" })
          vscode_map("n", { "<Down>", "J", "]b" }, "workbench.action.nextEditor", { desc = "Next Editor" })
          vscode_map({ "n", "v" }, "gk", "editor.action.showHover", { desc = "Hover" })
          vscode_map("n", "gK", "editor.action.triggerParameterHints", { desc = "Signature Help" })
          -- vscode_map("i", "<c-k>", "editor.action.triggerParameterHints", { desc = "Signature Help" }) -- not working
          vscode_map("n", "[B", "workbench.action.moveEditorLeftInGroup", { desc = "Move Editor Prev" })
          vscode_map("n", "]B", "workbench.action.moveEditorRightInGroup", { desc = "Move Editor Next" })
          vscode_map("n", { "[d", "[e" }, "editor.action.marker.prevInFiles", { desc = "Prev Diagnostic" })
          vscode_map("n", { "]d", "]e" }, "editor.action.marker.nextInFiles", { desc = "Next Diagnostic" })
          vscode_map("n", "[h", "editor.action.dirtydiff.previous", { desc = "Prev Hunk" })
          vscode_map("n", "]h", "editor.action.dirtydiff.next", { desc = "Next Hunk" })

          -- vscode_map("n", "gd", "editor.action.revealDefinition", { desc = "Goto Definition" })
          map("n", "<cr>", "gd", { desc = "Goto Definition/References", remap = true })
          -- map("n", "gr", function()
          --   vscode.action("editor.action.goToReferences", {
          --     callback = function()
          --       -- FIXME: first `v` after references not working
          --       vim.api.nvim_create_autocmd("ModeChanged", {
          --         group = vim.api.nvim_create_augroup("fix_auto_visual_after_references", { clear = true }),
          --         pattern = "n:v",
          --         once = true,
          --         callback = function()
          --           vim.cmd("normal! v")
          --         end,
          --       })
          --     end,
          --   })
          -- end, { desc = "References" })
          vscode_map("n", "gr", "editor.action.goToReferences", { desc = "References" })
          -- vscode_map("n", "gr", "editor.action.referenceSearch.trigger", { desc = "References" })
          vscode_map("n", "gy", "editor.action.goToTypeDefinition", { desc = "Goto T[y]pe Definition" })
          vscode_map("n", "gI", "editor.action.goToImplementation", { desc = "Goto Implementation" })

          map({ "i", "x", "n", "s" }, "<C-s>", "<cmd>w<cr><esc>", { desc = "Save File" })

          vscode_map("n", "<C-Down>", "workbench.action.increaseViewHeight")
          vscode_map("n", "<C-Up>", "workbench.action.decreaseViewHeight")
          vscode_map("n", "<C-Left>", "workbench.action.decreaseViewWidth")
          vscode_map("n", "<C-Right>", "workbench.action.increaseViewWidth")

          vscode_map("n", "zM", "editor.foldAll")
          vscode_map("n", "zR", "editor.unfoldAll")
          vscode_map("n", "zc", "editor.fold")
          vscode_map("n", "zC", "editor.foldRecursively")
          vscode_map("n", "zo", "editor.unfold")
          vscode_map("n", "zO", "editor.unfoldRecursively")
          vscode_map("n", "za", "editor.toggleFold")
          vscode_map("n", "zA", "editor.toggleFoldRecursively")
          vscode_map("n", "zj", "editor.gotoNextFold")
          vscode_map("n", "zk", "editor.gotoPreviousFold")
          vscode_map("v", "zf", "editor.createFoldingRangeFromSelection")
          vscode_map("n", "zd", "editor.removeManualFoldingRanges")

          vscode_map("n", "<leader>e", "workbench.view.explorer", { desc = "Explorer" })
          vscode_map("n", "<leader>n", "notifications.showList", { desc = "Notification History" })
          vscode_map("n", "<leader>z", "workbench.action.toggleZenMode", { desc = "Zen Mode" })

          -- map("n", { "<leader><space>", "<leader>ff" }, "<cmd>Find<cr>", { desc = "Find Files" })
          vscode_map("n", { "<leader><space>", "<leader>ff" }, "workbench.action.quickOpen", { desc = "Find Files" })
          vscode_map("n", "<leader>/", "workbench.action.findInFiles", { desc = "Grep" })
          -- https://github.com/vscode-neovim/vscode-neovim/issues/987#issuecomment-1201951589
          vscode_map(
            "n",
            { "<leader>`", "<leader>bb" },
            { "workbench.action.quickOpenPreviousRecentlyUsedEditorInGroup", "list.select" },
            { desc = "Switch to Other Buffer" }
          )
          vscode_map("n", "<leader>,", "workbench.action.showAllEditors", { desc = "Switch Editor" })
          vscode_map("n", { "<leader>:", "<leader>sc" }, "workbench.action.showCommands", { desc = "Commands" })

          -- github.copilot.chat.attachFile
          vscode_map(
            "n",
            "<leader>aa",
            is_cursor and "aichat.newchataction" or "workbench.action.chat.openInSidebar",
            { desc = "Copilot Chat" }
          )
          vscode_map(
            "v",
            "<leader>aa",
            is_cursor and "aichat.insertselectionintochat" or "github.copilot.chat.attachSelection",
            { desc = "Copilot Chat" }
          )
          vscode_map(
            { "n", "v" },
            "<leader>ae",
            is_cursor and "aipopup.action.modal.generate" or "inlineChat.start",
            { desc = "Inline Chat" }
          )
          vscode_map("n", "<leader>ar", "roo-cline.focusInput", { desc = "Roo Code" })

          for i = 1, 9 do
            vscode_map("n", "<leader>" .. i, "workbench.action.openEditorAtIndex" .. i, { desc = "Goto Editor " .. i })
          end
          vscode_map("n", "<leader>bd", "workbench.action.closeActiveEditor", { desc = "Close Editor" })
          vscode_map("n", "<leader>bo", "workbench.action.closeOtherEditors", { desc = "Close Other Editors" })
          vscode_map("n", "<leader>bA", "workbench.action.closeAllEditors", { desc = "Close All Editors" })
          -- copied from: https://github.com/Lxw0628/nvim/blob/e1c04bf500f5baae0b291836bedf64aaa186f51d/lua/plugins/vscode.lua#L75-L91
          map("n", "<leader>bp", function()
            if vscode.eval("return vscode.window.tabGroups.activeTabGroup.activeTab.isPinned") then
              vscode.action("workbench.action.unpinEditor")
            else
              vscode.action("workbench.action.pinEditor")
            end
          end, { desc = "Toggle Pin Editor" })
          map("n", "<leader>ba", function()
            vscode.eval([[
              vscode.window.tabGroups.all.forEach((tabGroup) => {
                tabGroup.tabs.forEach((tab) => {
                  if (!tab.isPinned) vscode.window.tabGroups.close(tab);
                });
              });
            ]])
          end, { desc = "Delete Non-Pinned Buffers" })
          -- stylua: ignore start
          vscode_map("n", "<leader>bh", "workbench.action.closeEditorsToTheLeft", { desc = "Close Editors to the Left" })
          vscode_map("n", "<leader>bl", "workbench.action.closeEditorsToTheRight", { desc = "Close Editors to the Right" })
          vscode_map("n", "<leader>bH", "workbench.action.firstEditorInGroup", { desc = "Goto First Editor" })
          vscode_map("n", "<leader>bL", "workbench.action.lastEditorInGroup", { desc = "Goto Last Editor" })

          vscode_map("n", "<leader>fc", "workbench.action.openSettingsJson", { desc = "Config File: Settings" })
          vscode_map("n", "<leader>fk", "workbench.action.openGlobalKeybindingsFile", { desc = "Config File: Keybindings" })
          vscode_map("n", "<leader>fn", "workbench.action.files.newUntitledFile", { desc = "New File" })
          vscode_map("n", "<leader>fS", "workbench.action.files.saveWithoutFormatting", { desc = "Save File Without Formatting" })
          -- stylua: ignore end
          -- vscode_map("n", "<leader>ft", "workbench.action.terminal.toggleTerminal", { desc = "Terminal" }) -- workbench.action.terminal.focus
          vscode_map("n", "<leader>fr", "workbench.action.showAllEditorsByMostRecentlyUsed", { desc = "Recent" })
          vscode_map("n", "<leader>fy", "workbench.action.files.copyPathOfActiveFile", { desc = "Yank file path" })
          vscode_map("n", "<leader>fY", "copyRelativeFilePath", { desc = "Yank file path from project" })
          -- -- https://marketplace.visualstudio.com/items?itemName=alefragnani.project-manager
          -- vscode_map("n", "<leader>fp", "projectManager.listProjectsNewWindow", { desc = "Projects" })
          vscode_map("n", "<leader>fp", "workbench.action.openRecent", { desc = "Projects" })

          map("n", "<leader>sw", function()
            vscode.action("workbench.action.findInFiles", { args = { query = vim.fn.expand("<cword>") } })
          end, { desc = "Grep Word" })
          vscode_map("v", "<leader>sw", "workbench.action.findInFiles", { desc = "Grep Visual Selection" })
          vscode_map("n", "<leader>sg", "workbench.action.quickTextSearch", { desc = "Quick text search" })
          vscode_map("n", "<leader>sk", "workbench.action.openGlobalKeybindings", { desc = "Key Maps" })
          vscode_map("n", "<leader>sC", "workbench.action.showCommands", { desc = "Commands" })
          vscode_map("n", "<leader>ss", "workbench.action.gotoSymbol", { desc = "Goto Symbol" })
          vscode_map("n", "<leader>sS", "workbench.action.showAllSymbols", { desc = "Goto Symbol (Workspace)" })
          vscode_map("n", "<leader>sna", "notifications.showList", { desc = "Noice All" })
          vscode_map("n", "<leader>snd", "notifications.clearAll", { desc = "Dismiss All" })

          vscode_map("n", "<leader>gg", "workbench.view.scm", { desc = "SCM" })

          map("n", "<leader>wh", "<C-w>h", { desc = "Go to the left window", remap = true })
          map("n", "<leader>wj", "<C-w>j", { desc = "Go to the down window", remap = true })
          map("n", "<leader>wk", "<C-w>k", { desc = "Go to the up window", remap = true })
          map("n", "<leader>wl", "<C-w>l", { desc = "Go to the right window", remap = true })
          map("n", "<leader>wH", "<C-w>H", { desc = "Move window to far left", remap = true })
          map("n", "<leader>wJ", "<C-w>J", { desc = "Move window to far bottom", remap = true })
          map("n", "<leader>wK", "<C-w>K", { desc = "Move window to far top", remap = true })
          map("n", "<leader>wL", "<C-w>L", { desc = "Move window to far right", remap = true })
          map("n", "<leader>ww", "<C-w>w", { desc = "Switch Windows", remap = true })
          map("n", "<leader>wv", "<C-w>v", { desc = "Split Window Right", remap = true })
          map("n", "<leader>ws", "<C-w>s", { desc = "Split Window Below", remap = true })
          map("n", "<leader>wo", "<C-w>o", { desc = "Delete Other Windows", remap = true })

          -- editor.action.codeAction = editor.action.quickFix + editor.action.refactor
          vscode_map({ "n", "v" }, "<leader>ca", "editor.action.codeAction", { desc = "Code Action" })
          vscode_map("n", "<leader>cA", "editor.action.sourceAction", { desc = "Source Action" })
          vscode_map("n", "<leader>cr", "editor.action.rename", { desc = "Rename" })
          vscode_map("n", "<leader>cf", "editor.action.formatDocument", { desc = "Format" })
          vscode_map("v", "<leader>cf", "editor.action.formatSelection", { desc = "Format" })
          vscode_map("n", "<leader>cF", "editor.action.formatDocument.multiple", { desc = "Format With" })
          vscode_map("v", "<leader>cF", "editor.action.formatSelection.multiple", { desc = "Format With" })
          vscode_map("n", "<leader>co", "editor.action.organizeImports", { desc = "Organize Imports" })

          vscode_map({ "n", "v" }, "<leader>rr", "editor.action.refactor", { desc = "Refactor" })
          -- https://code.visualstudio.com/docs/editor/refactoring#_keyboard-shortcuts-for-code-actions
          map("v", "<leader>rx", function()
            vscode.action("editor.action.codeAction", { args = { kind = "refactor.extract.variable" } })
          end, { desc = "Extract Variable" })

          vscode_map("n", "<leader>db", "editor.debug.action.toggleBreakpoint", { desc = "Toggle Breakpoint" })

          -- Toggle Wrap {{{

          -- vscode_map("n", "<leader>uw", "editor.action.toggleWordWrap", { desc = "Wrap" })
          local wrap = false
          local orig_keymaps = { n = {}, x = {} } ---@type table<string,table<string,table<string,any>>>
          map("n", "<leader>uw", function()
            wrap = not wrap
            vscode.action("editor.action.toggleWordWrap")
            if wrap then
              for mode, keymaps in pairs(orig_keymaps) do
                for _, lhs in ipairs({ "j", "k" }) do
                  keymaps[lhs] = vim.fn.maparg(lhs, mode, false, true) --[[@as table<string,any>]]
                end
              end
              -- fix: gj/gk doesn't work with editor.action.toggleWordWrap
              vscode_map("n", "j", "cursorDown", { desc = "VSCode Down" })
              vscode_map("n", "k", "cursorUp", { desc = "VSCode Up" })
              -- https://github.com/vscode-neovim/vscode-neovim/issues/576#issuecomment-1835799743
              -- https://github.com/vscode-neovim/vscode-neovim/blob/bb0389ac13c5215280cd0f66b32e80e3c916055c/runtime/vscode/overrides/vscode-motion.vim#L15
              local function move(d)
                return function()
                  -- only works in charwise visual mode
                  if vim.api.nvim_get_mode().mode ~= "v" then
                    return "g" .. d
                  end
                  local count = vim.v.count
                  local execute = count > 0 and vscode.call or vscode.action
                  execute("cursorMove", {
                    args = {
                      {
                        to = d == "j" and "down" or "up",
                        by = count == 0 and "wrappedLine" or nil,
                        value = count > 0 and count or 1,
                        select = true,
                      },
                    },
                  })
                  return count > 0 and "g" .. d or "<Ignore>"
                end
              end
              map("x", "j", move("j"), { desc = "VSCode Down", expr = true })
              map("x", "k", move("k"), { desc = "VSCode Up", expr = true })
            else
              for mode, keymaps in pairs(orig_keymaps) do
                for lhs, keymap in pairs(keymaps) do
                  if vim.tbl_isempty(keymap) then
                    vim.keymap.del(mode, lhs)
                  else
                    vim.fn.mapset(mode, false, keymap)
                  end
                end
              end
            end
          end, { desc = "Wrap" })

          -- }}}

          vscode_map("n", "<leader>uC", "workbench.action.selectTheme", { desc = "Colorscheme with Preview" })
          vscode_map("n", "<leader>un", "notifications.clearAll", { desc = "Dismiss All Notifications" })
          vscode_map("n", "<leader>uz", "workbench.action.toggleCenteredLayout")
          vscode_map("n", "<leader>uS", "workbench.action.toggleSidebarPosition")

          vscode_map("n", "<leader>xx", "workbench.actions.view.problems", { desc = "Diagnostics" })

          vscode_map("n", "<leader>qq", "workbench.action.closeWindow", { desc = "Quit All" })
        end,
      })

      vim.api.nvim_create_autocmd("FileType", {
        pattern = "markdown",
        callback = function(event)
          vscode_map("n", "<leader>cp", "markdown.showPreviewToSide", { buffer = event.buf, desc = "Markdown Preview" })
        end,
      })

      vim.api.nvim_create_autocmd("FileType", {
        pattern = "python",
        callback = function(event)
          vscode_map("n", "<leader>cv", "python.setInterpreter", { buffer = event.buf, desc = "Select VirtualEnv" })
        end,
      })

      -- TODO:
      -- https://code.visualstudio.com/docs/getstarted/keybindings
      -- https://github.com/archilkarchava/astronvim_config/blob/e4173cc3059c8aeca710b54c877533c7d5f8fc46/lua/plugins/vscode.lua
      -- https://github.com/AstroNvim/astrocommunity/blob/main/lua/astrocommunity/recipes/vscode/init.lua
      -- https://github.com/jellydn/my-nvim-ide/blob/e880b780c8d0efcebcaaf7d1443e7226d8d87804/lua/plugins/vscode.lua
      -- https://github.com/echasnovski/nvim/blob/b84cec54e0a46c9de824820fa8698b5bba43eb81/src/vscode.lua
      -- https://github.com/pojokcodeid/nvim-lazy/blob/ab014bb8b52ded6bc053f5b224574ac89bd18af9/init.lua
      -- https://github.com/kshenoy/dotfiles/blob/bd29a03df3c1f2df4273cb19dc54ed79eecaa5a5/nvim/lua/vscode-only/keybindings.lua
      -- https://github.com/Virgiel/my-config/blob/64c5c60c0be4a5f67fc7709017b3dd34ddc33376/config/nvim.lua#L25
      -- https://github.com/Matt-FTW/dotfiles/blob/7f14ad9d58fa5ee2aa971b77da4570c52f9aaa01/.config/nvim/lua/plugins/extras/util/vscode.lua
      -- https://github.com/jellydn/vscode-like-pro/blob/main/vscode.lua
      --
      -- https://github.com/corwinm/oil.code
    end,
  },
}
