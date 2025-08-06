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
  "blink-cmp-copilot",
  "plenary.nvim", -- for blink.cmp
  "conform.nvim",
  "nvim-lint",
  -- bash/fish
  "nvim-lspconfig",
  "mason.nvim", -- for nvim-lspconfig
  "mason-lspconfig.nvim",
}

local Config = require("lazy.core.config")
Config.options.checker.enabled = false
Config.options.change_detection.enabled = false
Config.options.defaults.cond = function(plugin)
  ---@diagnostic disable-next-line: undefined-field
  return vim.tbl_contains(enabled, plugin.name) or plugin.shell_command_editor
end
vim.g.snacks_animate = false

---@type LazySpec
return {
  {
    "snacks.nvim",
    ---@module "snacks"
    ---@param opts snacks.Config
    config = function(_, opts)
      local notify = vim.notify
      require("snacks").setup(vim.tbl_deep_extend("force", opts, {
        bigfile = { enabled = false },
        dashboard = { enabled = false },
        scroll = { enabled = false },
        image = { enabled = false },
        -- words = { enabled = false }, -- fish-lsp
      } --[[@as snacks.Config]]))
      if LazyVim.has("noice.nvim") then
        vim.notify = notify
      end
    end,
  },
  {
    "LazyVim/LazyVim",
    opts = function()
      vim.api.nvim_create_autocmd("User", {
        pattern = "LazyVimKeymaps",
        once = true,
        callback = function()
          vim.keymap.set("n", "<Esc>", function()
            if not U.keymap.clear_ui_esc() then
              if vim.g.user_close_key then
                vim.api.nvim_feedkeys(vim.keycode(vim.g.user_close_key), "m", false)
              else
                vim.cmd([[quit]])
              end
            end
          end, { desc = "Clear UI or Quit" })
        end,
      })

      local tmpdir = (vim.env.TMPDIR or "/tmp"):gsub("/$", "")
      vim.api.nvim_create_autocmd("BufRead", {
        group = vim.api.nvim_create_augroup("shell_command_buffer", { clear = true }),
        pattern = {
          tmpdir .. "/tmp.*.fish", -- https://github.com/fish-shell/fish-shell/blob/85ea9eefc62aced087a5f694dfcc76154fc1171b/share/functions/edit_command_buffer.fish#L2-L16
          tmpdir .. "/qutebrowser-editor-*", -- https://github.com/qutebrowser/qutebrowser/blob/7315c34957fd3b7c08d3314ba645eafd0eb6a815/qutebrowser/misc/editor.py#L118
        },
        once = true,
        callback = function(ev)
          vim.keymap.set("n", "<Esc>", function()
            if not U.keymap.clear_ui_esc() then
              vim.cmd([[quitall]])
            end
          end, { buffer = ev.buf, desc = "Clear UI or Exit" })

          -- https://github.com/chrisgrieser/.config/blob/052cf97e9e38a37b8d8ca921c3b6626851f98043/nvim/lua/config/autocmds.lua#L51-L74
          vim.api.nvim_create_autocmd({ "InsertLeave", "TextChanged" }, {
            group = vim.api.nvim_create_augroup("shell_command_buffer_autowrite", { clear = true }),
            buffer = ev.buf,
            callback = function()
              vim.api.nvim_buf_call(ev.buf, function()
                vim.cmd("silent! noautocmd lockmarks write")
              end)
            end,
          })
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
        if
          vim.list_contains({
            "lazydev",
            "dadbod",
            "avante",
            "avante_commands",
            "avante_mentions",
            "avante_shortcuts",
            "avante_files",
          }, sources_default[i])
        then
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
