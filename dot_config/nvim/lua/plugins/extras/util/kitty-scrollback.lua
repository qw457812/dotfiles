---@module "lazy"
---@type LazySpec
return {
  {
    "mikesmithgh/kitty-scrollback.nvim",
    cond = vim.g.terminal_scrollback_pager == true, -- disable for pager/manpager
    cmd = {
      "KittyScrollbackGenerateKittens",
      "KittyScrollbackCheckHealth",
      "KittyScrollbackGenerateCommandLineEditing",
    },
    event = "User KittyScrollbackLaunch",
    opts = function()
      local plug = require("kitty-scrollback.util").plug_mapping_names

      local augroup = vim.api.nvim_create_augroup("kitty_scrollback_keymaps", { clear = true })
      vim.api.nvim_create_autocmd("FileType", {
        group = augroup,
        pattern = "kitty-scrollback",
        callback = function(ev)
          if vim.g.user_close_key then
            vim.keymap.set("x", vim.g.user_close_key, function()
              vim.cmd.normal("y")
              vim.api.nvim_feedkeys(vim.keycode(vim.g.user_close_key), "m", false)
            end, { buffer = ev.buf, desc = "Yank and Quit" })
          end
        end,
      })

      -- HACK: keymaps for pastebufs
      local mapped_pastebufs = {} ---@type table<integer, boolean>
      vim.api.nvim_create_autocmd("BufWinEnter", {
        group = augroup,
        callback = vim.schedule_wrap(function()
          local buf = vim.api.nvim_get_current_buf()
          -- see: https://github.com/mikesmithgh/kitty-scrollback.nvim/blob/d8f5433153c4ff130fbef6095bd287b680ef2b6f/lua/kitty-scrollback/windows.lua#L110
          if vim.api.nvim_buf_get_name(buf):match("%.ksb_pastebuf$") and not mapped_pastebufs[buf] then
            mapped_pastebufs[buf] = true
            vim.keymap.set("n", "<cr>", plug.PASTE_CMD, { buffer = buf, desc = "Paste" })
            vim.keymap.set({ "n", "i" }, "<s-cr>", plug.EXECUTE_CMD, { buffer = buf, desc = "Execute" })
          end
        end),
      })
    end,
  },
}
