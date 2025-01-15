---@class util.telescope
local M = {}

---@param prompt_bufnr number
---@param direction number: 1 | -1
local function results_scrolling(prompt_bufnr, direction)
  local status = require("telescope.state").get_status(prompt_bufnr)
  local half_page = math.floor(vim.api.nvim_win_get_height(status.results_win) / 2)
  local results_size = vim.tbl_get(status, "picker", "manager", "info", "displayed") -- status(.layout).picker.manager.linked_states.size
  if type(results_size) == "number" and results_size <= half_page then
    if direction > 0 then
      return require("telescope.actions").move_to_bottom(prompt_bufnr)
    else
      return require("telescope.actions").move_to_top(prompt_bufnr)
    end
  end
  return require("telescope.actions.set").shift_selection(prompt_bufnr, half_page * (direction > 0 and 1 or -1))
end

M.actions = {
  ---@param prompt_bufnr number
  results_half_page_up = function(prompt_bufnr)
    return results_scrolling(prompt_bufnr, -1)
  end,

  ---@param prompt_bufnr number
  results_half_page_down = function(prompt_bufnr)
    return results_scrolling(prompt_bufnr, 1)
  end,
}

M.previewers = {
  --- set `scroll_fn` for never paging command by default
  ---@param opts table
  never_paging_term = function(opts)
    if not opts.scroll_fn then
      -- copied from:
      -- https://github.com/petobens/dotfiles/blob/0e216cdf8048859db5cbec0a1bc5b99d45479817/nvim/lua/plugin-config/telescope_config.lua#L35
      -- https://github.com/nvim-telescope/telescope.nvim/blob/85922dde3767e01d42a08e750a773effbffaea3e/lua/telescope/previewers/buffer_previewer.lua#L310
      function opts.scroll_fn(self, direction)
        if not self.state then
          return
        end

        -- local input = direction > 0 and string.char(0x05) or string.char(0x19)
        -- local input = direction > 0 and [[]] or [[]]
        -- https://github.com/nvim-telescope/telescope.nvim/issues/2933#issuecomment-1958504220
        local input = vim.keycode(direction > 0 and "<C-e>" or "<C-y>")
        local count = math.abs(direction)

        -- vim.api.nvim_win_call(vim.fn.bufwinid(self.state.termopen_bufnr), function()
        --   vim.cmd([[normal! ]] .. count .. input)
        -- end)
        vim.api.nvim_buf_call(self.state.termopen_bufnr, function()
          vim.cmd([[normal! ]] .. count .. input)
        end)
      end
    end

    return require("telescope.previewers").new_termopen_previewer(opts)
  end,

  -- https://github.com/petobens/dotfiles/blob/0e216cdf8048859db5cbec0a1bc5b99d45479817/nvim/lua/plugin-config/telescope_config.lua#L784
  tree = function()
    return M.previewers.never_paging_term({
      title = "Tree Preview",
      get_command = function(entry)
        local from_entry = require("telescope.from_entry")
        local utils = require("telescope.utils")

        local p = from_entry.path(entry, true, false)
        if p == nil or p == "" then
          return
        end
        local ignore_glob = ".DS_Store|.git|.svn|.idea|.vscode|node_modules"
        local command = vim.fn.executable("eza") == 1
            and {
              "eza",
              "--all",
              "--level=2",
              "--group-directories-first",
              "--ignore-glob=" .. ignore_glob,
              "--git-ignore",
              "--tree",
              "--color=always",
              "--color-scale",
              "all",
              "--icons=always",
              "--long",
              "--time-style=iso",
              "--git",
              "--no-permissions",
              "--no-user",
            }
          or { "tree", "-a", "-L", "2", "-I", ignore_glob, "-C", "--dirsfirst" }
        return utils.flatten({ command, "--", utils.path_expand(p) })
      end,
    })
  end,
}

---@param opts table
---@param path string
---@return string, table?
function M.path_display(opts, path)
  local utils = require("telescope.utils")
  local get_status = require("telescope.state").get_status
  local truncate = require("plenary.strings").truncate

  local transformed_path = U.path.shorten(vim.trim(path))

  -- truncate
  -- copy from: https://github.com/nvim-telescope/telescope.nvim/blob/bfcc7d5c6f12209139f175e6123a7b7de6d9c18a/lua/telescope/utils.lua#L198
  -- https://github.com/babarot/dotfiles/blob/cab2b7b00aef87efdf068d910e5e02935fecdd98/.config/nvim/lua/plugins/telescope.lua#L5
  local calc_result_length = function(truncate_len)
    local status = get_status(vim.api.nvim_get_current_buf())
    local len = vim.api.nvim_win_get_width(status.layout.results.winid) - status.picker.selection_caret:len() - 2
    return type(truncate_len) == "number" and len - truncate_len or len
  end
  local truncate_len = nil
  if opts.__length == nil then
    opts.__length = calc_result_length(truncate_len)
  end
  if opts.__prefix == nil then
    opts.__prefix = 0
  end
  transformed_path = truncate(transformed_path, opts.__length - opts.__prefix, nil, -1)

  -- filename_first style
  local tail = utils.path_tail(path)
  -- highlight group: Comment, TelescopeResultsComment, Constant, TelescopeResultsNumber, TelescopeResultsIdentifier
  local path_style = {
    { { 0, #transformed_path - #tail }, "Comment" },
    -- { { #transformed_path - #tail, #transformed_path }, "TelescopeResultsIdentifier" },
    { { #transformed_path, 999 }, "TelescopeResultsComment" },
  }
  return transformed_path, path_style
end

return M
