---@class util.telescope
local M = {}

--- set `scroll_fn` for never paging command by default
---@param opts table
function M.never_paging_term_previewer(opts)
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
end

return M
