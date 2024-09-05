if not vim.g.vscode or not LazyVim.has_extra("vscode") then
  return {}
end

local vscode = require("vscode")

---@param mode string|string[]
---@param lhs string
---@param rhs string|function
---@param opts? vim.keymap.set.Opts
local function map(mode, lhs, rhs, opts)
  opts = opts or {}
  opts.silent = opts.silent ~= false
  vim.keymap.set(mode, lhs, rhs, opts)
end

---@param mode string|string[]
---@param key string
---@param command string
---@param opts? vim.keymap.set.Opts
local function vscode_map(mode, key, command, opts)
  -- https://github.com/vscode-neovim/vscode-neovim#%EF%B8%8F-api
  -- stylua: ignore
  map(mode, key, function() vscode.action(command) end, opts)
end

-- https://github.com/LazyVim/LazyVim/pull/4392
function LazyVim.terminal()
  -- workbench.action.terminal.focus
  require("vscode").action("workbench.action.terminal.toggleTerminal")
end

vim.api.nvim_create_autocmd("User", {
  pattern = "LazyVimKeymaps",
  callback = function()
    vscode_map("n", "<Up>", "workbench.action.previousEditor", { desc = "Prev Editor" })
    vscode_map("n", "<Down>", "workbench.action.nextEditor", { desc = "Next Editor" })
    vscode_map("n", "[b", "workbench.action.previousEditor", { desc = "Prev Editor" })
    vscode_map("n", "]b", "workbench.action.nextEditor", { desc = "Next Editor" })
    vscode_map("n", "[B", "workbench.action.moveEditorLeftInGroup", { desc = "Move Editor Prev" })
    vscode_map("n", "]B", "workbench.action.moveEditorRightInGroup", { desc = "Move Editor Next" })
    vscode_map("n", "[d", "editor.action.marker.prevInFiles", { desc = "Prev Diagnostic" })
    vscode_map("n", "]d", "editor.action.marker.nextInFiles", { desc = "Next Diagnostic" })

    -- vscode_map("n", "gd", "editor.action.revealDefinition", { desc = "Goto Definition" })
    vscode_map("n", "gr", "editor.action.goToReferences", { desc = "References" })
    vscode_map("n", "gy", "editor.action.goToTypeDefinition", { desc = "Goto T[y]pe Definition" })
    vscode_map("n", "gI", "editor.action.goToImplementation", { desc = "Goto Implementation" })

    vscode_map("n", "<leader>e", "workbench.view.explorer", { desc = "Explorer" })
    vscode_map("n", "<leader>:", "workbench.action.showCommands", { desc = "All Commands" })
    vscode_map("n", "<leader>,", "workbench.action.showAllEditors", { desc = "All Editors" })
    -- vscode_map("n", "<leader>.", "workbench.action.terminal.focus", { desc = "Terminal" })

    vscode_map("n", "<leader>bd", "workbench.action.closeActiveEditor", { desc = "Close Editor" })
    vscode_map("n", "<leader>bo", "workbench.action.closeOtherEditors", { desc = "Close Other Editors" })
    vscode_map("n", "<leader>bp", "workbench.action.pinEditor", { desc = "Pin Editor" })
    vscode_map("n", "<leader>bP", "workbench.action.unpinEditor", { desc = "Unpin Editor" })

    vscode_map("n", "<leader>fc", "workbench.action.openSettingsJson", { desc = "Config File: Settings" })
    vscode_map("n", "<leader>fk", "workbench.action.openGlobalKeybindingsFile", { desc = "Config File: Keybindings" })
    vscode_map("n", "<leader>fn", "workbench.action.files.newUntitledFile", { desc = "New File" })
    -- vscode_map("n", "<leader>ft", "workbench.action.terminal.focus", { desc = "Terminal" })
    vscode_map("n", "<leader>fr", "workbench.action.showAllEditorsByMostRecentlyUsed", { desc = "Recent" }) -- workbench.action.quickOpenPreviousRecentlyUsedEditorInGroup
    vscode_map("n", "<leader>fy", "workbench.action.files.copyPathOfActiveFile", { desc = "Yank file path" })
    vscode_map("n", "<leader>fY", "copyRelativeFilePath", { desc = "Yank file path from project" })
    -- https://marketplace.visualstudio.com/items?itemName=alefragnani.project-manager
    vscode_map("n", "<leader>fp", "projectManager.listProjectsNewWindow", { desc = "Projects" })

    vscode_map("n", "<leader>sk", "workbench.action.openGlobalKeybindings", { desc = "Key Maps" })
    vscode_map("n", "<leader>sC", "workbench.action.showCommands", { desc = "Commands" })

    vscode_map("n", "<leader>gg", "workbench.view.scm", { desc = "SCM" })

    vscode_map("n", "<leader>ca", "editor.action.codeAction", { desc = "Code Action" })
    vscode_map("n", "<leader>cr", "editor.action.rename", { desc = "Rename" })
    vscode_map({ "n", "v" }, "<leader>cf", "editor.action.formatDocument", { desc = "Format" })

    vscode_map("n", "<leader>uw", "editor.action.toggleWordWrap", { desc = "Wrap" })
    vscode_map("n", "<leader>uC", "workbench.action.selectTheme", { desc = "Colorscheme with Preview" })

    vscode_map("n", "<leader>z", "workbench.action.toggleZenMode", { desc = "Zen Mode" })

    -- TODO:
    -- https://code.visualstudio.com/docs/getstarted/keybindings
    -- https://github.com/jellydn/my-nvim-ide/blob/e880b780c8d0efcebcaaf7d1443e7226d8d87804/lua/plugins/vscode.lua
    -- https://github.com/echasnovski/nvim/blob/b84cec54e0a46c9de824820fa8698b5bba43eb81/src/vscode.lua
    -- https://github.com/pojokcodeid/nvim-lazy/blob/ab014bb8b52ded6bc053f5b224574ac89bd18af9/init.lua
    -- https://github.com/kshenoy/dotfiles/blob/bd29a03df3c1f2df4273cb19dc54ed79eecaa5a5/nvim/lua/vscode-only/keybindings.lua
    -- https://github.com/Virgiel/my-config/blob/64c5c60c0be4a5f67fc7709017b3dd34ddc33376/config/nvim.lua#L25
  end,
})

return {}
