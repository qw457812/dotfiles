if vim.fn.executable("gemini") == 0 then
  return {}
end

local toggle_key = "<M-space>"

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
              -- fullscreen on termux
              height = vim.g.user_is_termux
                  ---@module "snacks"
                  ---@param self snacks.win
                  and function(self)
                    local bottom = (vim.o.cmdheight + (vim.o.laststatus == 3 and 1 or 0)) or 0
                    local top = (
                      vim.o.showtabline == 2 or (vim.o.showtabline == 1 and #vim.api.nvim_list_tabpages() > 1)
                    )
                        and 1
                      or 0
                    local border = self:border_size()
                    return vim.o.lines - top - bottom - border.top - border.bottom
                  end
                or nil,
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
