-- TODO: https://github.com/mikesmithgh/kitty-scrollback.nvim#command-line-editing
---@type LazySpec
return {
  {
    "mikesmithgh/kitty-scrollback.nvim",
    pager = true,
    -- cond = vim.env.KITTY_SCROLLBACK_NVIM == "true", -- needs pre-installation
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
              vim.cmd.normal({ "y", bang = true })
              vim.cmd.normal(vim.keycode(vim.g.user_close_key))
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
    config = function(_, opts)
      require("kitty-scrollback").setup(opts)

      if vim.g.user_kitty_scrollback_nvim_minimal then
        vim.defer_fn(function()
          -- https://github.com/mikesmithgh/kitty-scrollback.nvim/blob/e291b9e611a9c9ce25adad6bb1c4a9b850963de2/lua/kitty-scrollback/autocommands.lua#L138
          vim.api.nvim_clear_autocmds({
            group = vim.api.nvim_create_augroup("KittyScrollBackNvimTextYankPost", { clear = false }),
            event = "TextYankPost",
          })
        end, 100)
      end
    end,
  },
}
