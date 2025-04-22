return {
  {
    "yarospace/lua-console.nvim",
    keys = {
      {
        "<leader>'",
        function()
          local foldcolumn = vim.o.foldcolumn
          require("lua-console").toggle_console()
          if Lua_console.win then
            vim.wo[Lua_console.win].foldcolumn = foldcolumn
          end
        end,
        desc = "Toggle Lua Console",
      },
    },
    opts = {
      mappings = {
        toggle = false,
        attach = false,
        kill_ps = false,
        messages = "<localleader>m",
        save = "<localleader>s",
        load = "<localleader>l",
        help = "g?",
      },
    },
  },

  {
    "thenbe/csgithub.nvim",
    pager = true,
    keys = function()
      local function search(args)
        if vim.fn.expand("%:e") == "" then
          args = args or {}
          args.includeExtension = false
        end
        local url = require("csgithub").search(args)
        -- https://github.com/thenbe/csgithub.nvim/blob/9df37440ba1bbf95f0a328819090353654ca4f55/lua/csgithub/init.lua#L26-L29
        if not url or url == "" then
          LazyVim.error("URL is empty!", { title = "Csgithub" })
          return
        end
        vim.ui.open(url, vim.g.user_is_termux and {
          cmd = {
            "am",
            "start",
            "-n",
            "com.kiwibrowser.browser/com.google.android.apps.chrome.Main",
            "-d",
          },
        } or nil)
      end

      return {
        { "<leader>/", mode = "x", search, desc = "GitHub Code Search (extension)" },
        {
          "<leader>?",
          mode = "x",
          function()
            search({ includeFilename = true })
          end,
          desc = "GitHub Code Search (filename)",
        },
      }
    end,
  },
}
