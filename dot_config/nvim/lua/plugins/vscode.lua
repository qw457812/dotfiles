if not vim.g.vscode then
  return {}
end

local vscode = require("vscode")
local map = U.keymap.map

-- vim.notify = vscode.notify
-- vim.g.clipboard = vim.g.vscode_clipboard

---@param mode string|string[]
---@param key string|string[]
---@param command string|string[]
---@param opts? vim.keymap.set.Opts
local function vscode_map(mode, key, command, opts)
  ---@cast command string[]
  command = type(command) == "string" and { command } or command

  -- https://github.com/vscode-neovim/vscode-neovim#%EF%B8%8F-api
  local execute = #command == 1 and vscode.action or vscode.call

  map(mode, key, function()
    for _, c in ipairs(command) do
      execute(c)
    end
  end, opts)
end

return {
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
          vscode_map("n", "u", "undo", { desc = "VSCode Undo" })
          vscode_map("n", { "<C-r>", "U" }, "redo", { desc = "VSCode Redo" })

          vscode_map("n", "<Left>", "workbench.action.navigateBack", { desc = "Go Back" })
          vscode_map("n", "<Right>", "workbench.action.navigateForward", { desc = "Go Forward" })

          vscode_map("n", { "<Up>", "K", "[b" }, "workbench.action.previousEditor", { desc = "Prev Editor" })
          vscode_map("n", { "<Down>", "J", "]b" }, "workbench.action.nextEditor", { desc = "Next Editor" })
          vscode_map({ "n", "v" }, "gk", "editor.action.showHover", { desc = "Hover" })
          vscode_map("n", "[B", "workbench.action.moveEditorLeftInGroup", { desc = "Move Editor Prev" })
          vscode_map("n", "]B", "workbench.action.moveEditorRightInGroup", { desc = "Move Editor Next" })
          vscode_map("n", "[d", "editor.action.marker.prevInFiles", { desc = "Prev Diagnostic" })
          vscode_map("n", "]d", "editor.action.marker.nextInFiles", { desc = "Next Diagnostic" })
          vscode_map("n", "[h", "editor.action.dirtydiff.previous", { desc = "Prev Hunk" })
          vscode_map("n", "]h", "editor.action.dirtydiff.next", { desc = "Next Hunk" })

          -- vscode_map("n", "gd", "editor.action.revealDefinition", { desc = "Goto Definition" })
          map("n", "<cr>", "gd", { desc = "Goto Definition/References", remap = true })
          vscode_map("n", "gr", "editor.action.goToReferences", { desc = "References" })
          -- vscode_map("n", "gr", "editor.action.referenceSearch.trigger", { desc = "References" })
          vscode_map("n", "gy", "editor.action.goToTypeDefinition", { desc = "Goto T[y]pe Definition" })
          vscode_map("n", "gI", "editor.action.goToImplementation", { desc = "Goto Implementation" })

          vscode_map("n", "<C-Down>", "workbench.action.increaseViewHeight")
          vscode_map("n", "<C-Up>", "workbench.action.decreaseViewHeight")
          vscode_map("n", "<C-Left>", "workbench.action.decreaseViewWidth")
          vscode_map("n", "<C-Right>", "workbench.action.increaseViewWidth")

          vscode_map("n", "<leader>e", "workbench.view.explorer", { desc = "Explorer" })
          vscode_map("n", "<leader>z", "workbench.action.toggleZenMode", { desc = "Zen Mode" })

          -- map("n", { "<leader><space>", "<leader>ff" }, "<cmd>Find<cr>", { desc = "Find Files" })
          vscode_map("n", { "<leader><space>", "<leader>ff" }, "workbench.action.quickOpen", { desc = "Find Files" })
          vscode_map("n", { "<leader>/", "<leader>sg" }, "workbench.action.findInFiles", { desc = "Grep" })
          -- https://github.com/vscode-neovim/vscode-neovim/issues/987#issuecomment-1201951589
          vscode_map(
            "n",
            { "<leader>`", "<leader>bb" },
            { "workbench.action.quickOpenPreviousRecentlyUsedEditorInGroup", "list.select" },
            { desc = "Switch to Other Buffer" }
          )
          vscode_map("n", "<leader>,", "workbench.action.showAllEditors", { desc = "Switch Editor" })
          vscode_map("n", { "<leader>:", "<leader>sc" }, "workbench.action.showCommands", { desc = "Commands" })

          vscode_map("n", "<leader>bd", "workbench.action.closeActiveEditor", { desc = "Close Editor" })
          vscode_map("n", "<leader>bo", "workbench.action.closeOtherEditors", { desc = "Close Other Editors" })
          vscode_map("n", "<leader>bA", "workbench.action.closeAllEditors", { desc = "Close All Editors" })
          vscode_map("n", "<leader>bp", "workbench.action.pinEditor", { desc = "Pin Editor" })
          vscode_map("n", "<leader>bP", "workbench.action.unpinEditor", { desc = "Unpin Editor" })
          vscode_map(
            "n",
            "<leader>bh",
            "workbench.action.closeEditorsToTheLeft",
            { desc = "Close Editors to the Left" }
          )
          vscode_map(
            "n",
            "<leader>bl",
            "workbench.action.closeEditorsToTheRight",
            { desc = "Close Editors to the Right" }
          )
          vscode_map("n", "<leader>bH", "workbench.action.firstEditorInGroup", { desc = "Goto First Editor" })
          vscode_map("n", "<leader>bL", "workbench.action.lastEditorInGroup", { desc = "Goto Last Editor" })
          for i = 1, 9 do
            vscode_map("n", "<leader>b" .. i, "workbench.action.openEditorAtIndex" .. i, { desc = "Goto Editor " .. i })
          end

          vscode_map("n", "<leader>fc", "workbench.action.openSettingsJson", { desc = "Config File: Settings" })
          vscode_map(
            "n",
            "<leader>fk",
            "workbench.action.openGlobalKeybindingsFile",
            { desc = "Config File: Keybindings" }
          )
          vscode_map("n", "<leader>fn", "workbench.action.files.newUntitledFile", { desc = "New File" })
          -- stylua: ignore
          vscode_map("n", "<leader>fS", "workbench.action.files.saveWithoutFormatting", { desc = "Save File Without Formatting" })
          -- vscode_map("n", "<leader>ft", "workbench.action.terminal.focus", { desc = "Terminal" })
          vscode_map("n", "<leader>ft", "workbench.action.terminal.toggleTerminal", { desc = "Terminal" })
          vscode_map("n", "<leader>fr", "workbench.action.showAllEditorsByMostRecentlyUsed", { desc = "Recent" })
          vscode_map("n", "<leader>fy", "workbench.action.files.copyPathOfActiveFile", { desc = "Yank file path" })
          vscode_map("n", "<leader>fY", "copyRelativeFilePath", { desc = "Yank file path from project" })
          -- -- https://marketplace.visualstudio.com/items?itemName=alefragnani.project-manager
          -- vscode_map("n", "<leader>fp", "projectManager.listProjectsNewWindow", { desc = "Projects" })
          vscode_map("n", "<leader>fp", "workbench.action.openRecent", { desc = "Projects" })

          vscode_map("n", "<leader>sk", "workbench.action.openGlobalKeybindings", { desc = "Key Maps" })
          vscode_map("n", "<leader>sC", "workbench.action.showCommands", { desc = "Commands" })
          vscode_map("n", "<leader>ss", "workbench.action.gotoSymbol", { desc = "Goto Symbol" })
          -- vscode_map("n", "<leader>sS", "workbench.action.showAllSymbols", { desc = "Goto Symbol (Workspace)" })
          vscode_map("n", "<leader>sna", "notifications.showList", { desc = "Noice All" })

          vscode_map("n", "<leader>gg", "workbench.view.scm", { desc = "SCM" })

          -- editor.action.codeAction = editor.action.quickFix + editor.action.refactor
          vscode_map({ "n", "v" }, "<leader>ca", "editor.action.codeAction", { desc = "Code Action" })
          vscode_map("n", "<leader>cA", "editor.action.sourceAction", { desc = "Source Action" })
          vscode_map("n", "<leader>cr", "editor.action.rename", { desc = "Rename" })
          vscode_map({ "n", "v" }, "<leader>cf", "editor.action.formatDocument", { desc = "Format" })
          vscode_map("n", "<leader>co", "editor.action.organizeImports", { desc = "Organize Imports" })

          vscode_map("v", "<leader>rs", "editor.action.refactor", { desc = "Refactor" })
          -- https://code.visualstudio.com/docs/editor/refactoring#_keybindings-for-code-actions
          map("v", "<leader>rx", function()
            vscode.action("editor.action.codeAction", { args = { kind = "refactor.extract.variable" } })
          end, { desc = "Extract Variable" })

          vscode_map("n", "<leader>db", "editor.debug.action.toggleBreakpoint", { desc = "Toggle Breakpoint" })

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
                    vim.fn.mapset(keymap)
                  end
                end
              end
            end
          end, { desc = "Wrap" })
          vscode_map("n", "<leader>uC", "workbench.action.selectTheme", { desc = "Colorscheme with Preview" })

          vscode_map("n", "<leader>xx", "workbench.actions.view.problems", { desc = "Diagnostics" })

          vim.api.nvim_create_autocmd("FileType", {
            pattern = "markdown",
            callback = function(event)
              vscode_map(
                "n",
                "<leader>cp",
                "markdown.showPreviewToSide",
                { buffer = event.buf, desc = "Markdown Preview" }
              )
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
          -- https://github.com/AstroNvim/astrocommunity/blob/main/lua/astrocommunity/recipes/vscode/init.lua
          -- https://github.com/jellydn/my-nvim-ide/blob/e880b780c8d0efcebcaaf7d1443e7226d8d87804/lua/plugins/vscode.lua
          -- https://github.com/echasnovski/nvim/blob/b84cec54e0a46c9de824820fa8698b5bba43eb81/src/vscode.lua
          -- https://github.com/pojokcodeid/nvim-lazy/blob/ab014bb8b52ded6bc053f5b224574ac89bd18af9/init.lua
          -- https://github.com/kshenoy/dotfiles/blob/bd29a03df3c1f2df4273cb19dc54ed79eecaa5a5/nvim/lua/vscode-only/keybindings.lua
          -- https://github.com/Virgiel/my-config/blob/64c5c60c0be4a5f67fc7709017b3dd34ddc33376/config/nvim.lua#L25
          -- https://github.com/Matt-FTW/dotfiles/blob/7f14ad9d58fa5ee2aa971b77da4570c52f9aaa01/.config/nvim/lua/plugins/extras/util/vscode.lua
          -- https://github.com/jellydn/vscode-like-pro/blob/main/vscode.lua
        end,
      })
    end,
  },
}
