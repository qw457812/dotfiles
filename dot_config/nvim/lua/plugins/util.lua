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
    keys = function()
      local function search(args)
        local csgithub = require("csgithub")
        local url = csgithub.search(args)
        if url and vim.g.user_is_termux then
          vim.fn.setreg(vim.v.register, url)
          LazyVim.info(url, { title = "Copied URL" })
        else
          csgithub.open(url)
        end
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
