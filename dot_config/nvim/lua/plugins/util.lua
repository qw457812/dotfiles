---@type LazySpec
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
    vscode = true,
    pager = true,
    keys = function()
      local function search(args)
        if vim.fn.expand("%:e") == "" then
          args = args or {}
          args.includeExtension = false
        end
        local url = require("csgithub").search(args)
        -- https://github.com/thenbe/csgithub.nvim/blob/9df37440ba1bbf95f0a328819090353654ca4f55/lua/csgithub/init.lua#L26-L29
        if url and url ~= "" then
          U.open_in_browser(url)
        else
          LazyVim.error("URL is empty!", { title = "Csgithub" })
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

  {
    "alex-popov-tech/store.nvim",
    enabled = not vim.g.user_is_termux, -- error on termux
    cmd = "Store",
    keys = {
      { "<leader>lh", "<cmd>Store<cr>", desc = "Plugin Hub" },
    },
    ---@module "store"
    ---@type UserConfig
    opts = {
      width = 0.95,
      height = 0.9,
      keybindings = {
        hover = { "gk" },
      },
    },
  },
}
