if vim.fn.executable("gemini") == 0 then
  return {}
end

local toggle_key = "<M-,>"

---@type LazySpec
return {
  {
    "folke/snacks.nvim",
    keys = {
      {
        toggle_key,
        function()
          U.terminal("gemini", {
            win = {
              keys = {
                opencode_close = {
                  toggle_key,
                  function(self)
                    self:hide()
                  end,
                  mode = "t",
                  desc = "Close",
                },
              },
              b = { user_lualine_filename = "gemini-cli" },
              height = vim.g.user_is_termux and U.snacks.win.fullscreen_height or nil,
              width = vim.g.user_is_termux and 0 or nil,
            },
            cwd = LazyVim.root(),
          })
        end,
        desc = "Gemini CLI",
      },
    },
  },
}
