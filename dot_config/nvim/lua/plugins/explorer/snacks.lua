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
              reset_input = function(picker)
                picker.input:set("", "")
              end,
              -- copied from: https://github.com/folke/snacks.nvim/blob/938aee4a02119ad693a67c38b64a9b3232a72565/lua/snacks/explorer/actions.lua#L104-L114
              parent_or_close = function(picker, item)
                local Actions = require("snacks.explorer.actions")
                local Tree = require("snacks.explorer.tree")

                if not item then
                  return
                end
                local dir = picker:dir()
                if dir == picker:cwd() then
                  Actions.actions.explorer_up(picker)
                end
                if item.dir and not item.open then
                  dir = vim.fs.dirname(dir)
                end
                Tree:close(dir)
                Actions.update(picker, { target = dir, refresh = true })
              end,
              -- copied from: https://github.com/folke/snacks.nvim/blob/938aee4a02119ad693a67c38b64a9b3232a72565/lua/snacks/explorer/actions.lua#L276-L287
              child_or_open = function(picker, item, action)
                local Actions = require("snacks.explorer.actions")
                local Tree = require("snacks.explorer.tree")

                if not item then
                  return
                elseif picker.input.filter.meta.searching then
                  Actions.update(picker, { target = item.file })
                elseif item.dir then
                  local dir = Tree:dir(item.file)
                  local node = Tree:find(dir)
                  if node.open then
                    Snacks.picker.actions.list_down(picker)
                  else
                    Tree:open(dir)
                    Actions.update(picker, { refresh = true })
                  end
                else
                  Snacks.picker.actions.jump(picker, item, action)
                  if vim.g.user_explorer_auto_close or too_narrow() then
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
                  ["h"] = "parent_or_close",
                  ["l"] = "child_or_open",
                  ["f"] = "focus_input", -- filter
                },
              },
              input = {
                keys = {
                  ["<Esc>"] = {
                    "<Esc>",
                    function(self)
                      if not U.keymap.clear_ui_esc({ close = false }) then
                        self:execute(self:line() ~= "" and "reset_input" or "focus_list")
                      end
                    end,
                    desc = "Clear UI or Reset Input or Focus List",
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
          picker:action("focus_list")
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
