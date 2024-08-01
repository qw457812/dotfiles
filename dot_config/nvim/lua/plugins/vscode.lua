if not vim.g.vscode or not LazyVim.has_extra("vscode") then
  return {}
end

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
  map(mode, key, "<cmd>call VSCodeNotify('" .. command .. "')<cr>", opts)
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

    -- vscode_map("n", "gd", "editor.action.revealDefinition", { desc = "Goto Definition" })
    vscode_map("n", "gr", "editor.action.goToReferences", { desc = "References" })
    vscode_map("n", "gy", "editor.action.goToTypeDefinition", { desc = "Goto T[y]pe Definition" })
    vscode_map("n", "gI", "editor.action.goToImplementation", { desc = "Goto Implementation" })

    vscode_map("n", "<leader>e", "workbench.view.explorer", { desc = "Explorer" })
    vscode_map("n", "<leader>:", "workbench.action.showCommands", { desc = "Show Commands" })
    vscode_map("n", "<leader>,", "workbench.action.showAllEditors", { desc = "All Editors" })
    vscode_map("n", "<leader>.", "workbench.action.terminal.focus", { desc = "Terminal" })

    vscode_map("n", "<leader>bd", "workbench.action.closeActiveEditor", { desc = "Close Editor" })
    vscode_map("n", "<leader>bo", "workbench.action.closeOtherEditors", { desc = "Close Other Editors" })
    vscode_map("n", "<leader>bp", "workbench.action.pinEditor", { desc = "Pin Editor" })
    vscode_map("n", "<leader>bP", "workbench.action.unpinEditor", { desc = "Unpin Editor" })

    vscode_map("n", "<leader>fc", "workbench.action.openSettingsJson", { desc = "Settings File" })
    vscode_map("n", "<leader>fk", "workbench.action.openGlobalKeybindingsFile", { desc = "Keybindings File" })
    vscode_map("n", "<leader>fn", "workbench.action.files.newUntitledFile", { desc = "New File" })
    vscode_map("n", "<leader>ft", "workbench.action.terminal.focus", { desc = "Terminal" })
    vscode_map("n", "<leader>fy", "workbench.action.files.copyPathOfActiveFile", { desc = "Yank file path" })
    vscode_map("n", "<leader>fY", "copyRelativeFilePath", { desc = "Yank file path from project" })
    -- https://marketplace.visualstudio.com/items?itemName=alefragnani.project-manager
    vscode_map("n", "<leader>fp", "projectManager.listProjectsNewWindow", { desc = "Projects" })

    vscode_map("n", "<leader>ca", "editor.action.codeAction", { desc = "Code Action" })
    vscode_map("n", "<leader>cr", "editor.action.rename", { desc = "Rename" })
    vscode_map({ "n", "v" }, "<leader>cf", "editor.action.formatDocument", { desc = "Format" })

    -- TODO:
    -- https://github.com/pojokcodeid/nvim-lazy/blob/ab014bb8b52ded6bc053f5b224574ac89bd18af9/init.lua
    -- https://github.com/kshenoy/dotfiles/blob/bd29a03df3c1f2df4273cb19dc54ed79eecaa5a5/nvim/lua/vscode-only/keybindings.lua
    -- https://github.com/Virgiel/my-config/blob/64c5c60c0be4a5f67fc7709017b3dd34ddc33376/config/nvim.lua#L25
  end,
})

return {}
