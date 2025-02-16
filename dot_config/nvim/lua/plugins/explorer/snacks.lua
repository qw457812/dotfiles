---@param win? integer
local function too_narrow(win)
  return vim.o.columns < 120 or vim.api.nvim_win_get_width(win or 0) < 120
end

---@diagnostic disable: missing-fields
return {
  {
    "folke/snacks.nvim",
    ---@module "snacks"
    ---@type snacks.Config
    opts = {
      explorer = {
        replace_netrw = vim.g.user_hijack_netrw == "snacks.nvim",
      },
      picker = {
        sources = {
          explorer = {
            actions = {
              unfocus = function(picker)
                local _, win = picker:current_win()
                if not win then
                  return
                end
                vim.cmd.wincmd("p")
                if win.win == vim.api.nvim_get_current_win() then
                  vim.cmd.wincmd("l")
                end
              end,
              close_or_unfocus = function(picker)
                if vim.g.user_explorer_auto_close then
                  picker:close()
                else
                  picker:action("unfocus")
                  if too_narrow() then
                    picker:close()
                  end
                end
              end,
            },
            win = {
              list = {
                keys = {
                  ["<Esc>"] = {
                    "<Esc>",
                    function(self)
                      if not U.keymap.clear_ui_esc({ close = false }) then
                        self:execute("close_or_unfocus")
                      end
                    end,
                    desc = "Clear UI or Close or Unfocus",
                  },
                  ["f"] = "focus_input", -- filter
                },
              },
              input = {
                keys = {
                  ["<Esc>"] = {
                    "<Esc>",
                    function(self)
                      if not U.keymap.clear_ui_esc({ close = false }) then
                        self:execute("focus_list")
                      end
                    end,
                    desc = "Clear UI or Focus List",
                  },
                },
              },
            },
          },
        },
      },
    },
    keys = function(_, keys)
      if not LazyVim.has_extra("editor.snacks_explorer") then
        return
      end

      ---@param opts? snacks.picker.explorer.Config|{}
      local function toggle(opts)
        local picker = Snacks.picker.get({ source = "explorer" })[1]
        if not picker then
          Snacks.explorer(opts)
        elseif picker:is_focused() then
          picker:action("close_or_unfocus")
        else
          local win = picker.layout.wins.list
          if win then
            win:focus()
          end
        end
      end

      vim.list_extend(keys, {
        {
          "<leader>fe",
          function()
            toggle({ cwd = LazyVim.root() })
          end,
          desc = "Explorer Snacks (root dir)",
        },
        { "<leader>fE", toggle, desc = "Explorer Snacks (cwd)" },
      })
    end,
  },
}
