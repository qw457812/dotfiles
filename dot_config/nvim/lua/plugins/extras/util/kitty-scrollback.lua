-- TODO: https://github.com/mikesmithgh/kitty-scrollback.nvim#command-line-editing
---@type LazySpec
return {
  {
    "mikesmithgh/kitty-scrollback.nvim",
    pager = true,
    -- cond = vim.env.KITTY_SCROLLBACK_NVIM == "true", -- needs pre-installation
    cond = vim.g.user_is_kitty,
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

          local win = vim.fn.bufwinid(ev.buf)
          if win ~= -1 then
            vim.wo[win].sidescrolloff = 0
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
        local function autocmds_opts()
          -- https://github.com/mikesmithgh/kitty-scrollback.nvim/blob/e291b9e611a9c9ce25adad6bb1c4a9b850963de2/lua/kitty-scrollback/autocommands.lua#L138
          return {
            group = vim.api.nvim_create_augroup("KittyScrollBackNvimTextYankPost", { clear = false }),
            event = "TextYankPost",
          }
        end
        local function has_autocmds()
          return #vim.api.nvim_get_autocmds(autocmds_opts()) > 0
        end
        local function clear_autocmds()
          vim.api.nvim_clear_autocmds(autocmds_opts())
        end

        -- schedule: align with https://github.com/mikesmithgh/kitty-scrollback.nvim/blob/78fdd7a598ef095d34980a0b23b793bdaf47992e/lua/kitty-scrollback/launch.lua#L377-L390
        vim.schedule(function()
          -- schedule: make sure kitty-scrollback.nvim has set up its autocmds
          vim.schedule(function()
            if has_autocmds() then
              clear_autocmds()
            else
              LazyVim.warn(
                "This should not happen, check the setup of autocmds in kitty-scrollback.nvim.",
                { title = "vim.g.user_kitty_scrollback_nvim_minimal" }
              )

              -- local polls = 0
              -- local start = vim.uv.hrtime()
              -- local done = vim.wait(50, function()
              --   polls = polls + 1
              --   return has_autocmds()
              -- end, 10)
              -- local elapsed = (vim.uv.hrtime() - start) / 1e6
              -- Snacks.debug.inspect({ done = done, polls = polls, elapsed = string.format("%.2fms", elapsed) })
              -- if done then
              --   clear_autocmds()
              -- end

              vim.defer_fn(clear_autocmds, 1)
            end
          end)
        end)
      end
    end,
  },
}
