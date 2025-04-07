if not vim.g.shell_command_editor then
  return {}
end

local enabled = {
  "LazyVim",
  "lazy.nvim",
  "snacks.nvim",
  "mini.ai",
  "mini.move",
  "mini.pairs",
  "mini.surround",
  "nvim-treesitter",
  "nvim-treesitter-textobjects",
  "ts-comments.nvim",
  "dial.nvim",
  "yanky.nvim",
  "which-key.nvim",
  "tokyonight.nvim",
  "lualine.nvim",
  "mini.icons", -- for lualine.nvim
  "noice.nvim",
  "nui.nvim", -- for noice.nvim
  "vim-illuminate",
  "blink.cmp",
  "blink.compat",
  "friendly-snippets",
  "mini.snippets",
  "copilot.lua",
  "blink-copilot",
  "plenary.nvim", -- for blink.cmp
  "conform.nvim",
  "nvim-lint",
  -- -- bash
  -- "nvim-lspconfig",
  -- "mason.nvim", -- for nvim-lspconfig
  -- "mason-lspconfig.nvim",
}

local Config = require("lazy.core.config")
Config.options.checker.enabled = false
Config.options.change_detection.enabled = false
Config.options.defaults.cond = function(plugin)
  return vim.tbl_contains(enabled, plugin.name) or plugin.shell_command_editor
end
vim.g.snacks_animate = false

return {
  {
    "snacks.nvim",
    ---@module "snacks"
    ---@param opts snacks.Config
    config = function(_, opts)
      ---@type snacks.Config
      local o = {
        bigfile = { enabled = false },
        dashboard = { enabled = false },
        scroll = { enabled = false },
        image = { enabled = false },
        words = { enabled = false },
      }
      local notify = vim.notify
      require("snacks").setup(vim.tbl_deep_extend("force", opts, o))
      if LazyVim.has("noice.nvim") then
        vim.notify = notify
      end
    end,
  },
  {
    "LazyVim/LazyVim",
    opts = function()
      if vim.o.shell:find("fish") then
        local augroup = vim.api.nvim_create_augroup("shell_command_editor_autowrite", { clear = true })
        vim.api.nvim_create_autocmd("BufRead", {
          group = augroup,
          pattern = (vim.env.TMPDIR or "/tmp"):gsub("/$", "") .. "/tmp.*.fish",
          once = true,
          callback = function(ev)
            vim.api.nvim_create_autocmd({ "InsertLeave", "TextChanged" }, {
              group = augroup,
              buffer = ev.buf,
              callback = function()
                vim.api.nvim_buf_call(ev.buf, function()
                  vim.cmd("silent! noautocmd lockmarks write")
                end)
              end,
            })
          end,
        })
      end

      vim.api.nvim_create_autocmd("User", {
        pattern = "LazyVimKeymaps",
        once = true,
        callback = function()
          vim.keymap.set("n", "<Esc>", function()
            if not U.keymap.clear_ui_esc() then
              vim.cmd([[quit]])
            end
          end, { desc = "Clear UI or Quit" })
        end,
      })
    end,
    config = function(_, opts)
      opts.colorscheme = LazyVim.has("tokyonight.nvim") and "tokyonight-moon" or function() end
      require("lazyvim").setup(opts)
    end,
  },
  {
    "nvim-lualine/lualine.nvim",
    optional = true,
    config = function(_, opts)
      -- stylua: ignore start
      opts.sections.lualine_a = { { function() return (vim.o.shell:match("[^/]+$") or "shell"):upper() end } }
      opts.sections.lualine_b = { { function() return "command" end } }
      opts.sections.lualine_c = {
        {
          function() return " " end,
          color = function() return { fg = Snacks.util.color(vim.bo.modified and "MatchParen" or "MiniIconsGreen") } end,
        },
      }
      -- stylua: ignore end
      opts.sections.lualine_x = { U.lualine.hlsearch, U.lualine.command }
      opts.sections.lualine_y = { { "progress" } }
      opts.extensions = {}
      require("lualine").setup(opts)
    end,
  },
  {
    "saghen/blink.cmp",
    optional = true,
    ---@module 'blink.cmp'
    ---@param opts blink.cmp.Config
    opts = function(_, opts)
      local sources_default = opts.sources.default
      if type(sources_default) ~= "table" then
        return
      end
      for i = #sources_default, 1, -1 do
        if vim.list_contains({ "lazydev", "dadbod", "avante" }, sources_default[i]) then
          table.remove(sources_default, i)
        end
      end
    end,
  },
  {
    "neovim/nvim-lspconfig",
    optional = true,
    opts = function(_, opts)
      opts.setup.metals = nil
    end,
  },
}
