if vim.fn.executable("gemini") == 0 then
  return {}
end

local toggle_key = "<M-space>"

---@module "lazy"
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
              position = "float",
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
            },
            cwd = LazyVim.root(),
          })
        end,
        desc = "Gemini CLI",
      },
    },
  },
}
