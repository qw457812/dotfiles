return {
  -- :h bufferline-configuration
  {
    "akinsho/bufferline.nvim",
    keys = {
      { "<Up>", "<cmd>BufferLineCyclePrev<cr>", desc = "Prev Buffer" },
      { "<Down>", "<cmd>BufferLineCycleNext<cr>", desc = "Next Buffer" },
      { "<leader>bH", "<cmd>BufferLineGoToBuffer 1<cr>", desc = "Goto First Buffer" },
      -- { "<leader>b1", "<cmd>BufferLineGoToBuffer 1<cr>", desc = "Goto Buffer 1" },
      -- { "<leader>b2", "<cmd>BufferLineGoToBuffer 2<cr>", desc = "Goto Buffer 2" },
      -- { "<leader>b3", "<cmd>BufferLineGoToBuffer 3<cr>", desc = "Goto Buffer 3" },
      -- { "<leader>b4", "<cmd>BufferLineGoToBuffer 4<cr>", desc = "Goto Buffer 4" },
      -- { "<leader>b5", "<cmd>BufferLineGoToBuffer 5<cr>", desc = "Goto Buffer 5" },
      -- { "<leader>b6", "<cmd>BufferLineGoToBuffer 6<cr>", desc = "Goto Buffer 6" },
      -- { "<leader>b7", "<cmd>BufferLineGoToBuffer 7<cr>", desc = "Goto Buffer 7" },
      -- { "<leader>b8", "<cmd>BufferLineGoToBuffer 8<cr>", desc = "Goto Buffer 8" },
      -- { "<leader>b9", "<cmd>BufferLineGoToBuffer 9<cr>", desc = "Goto Buffer 9" },
      { "<leader>bL", "<cmd>BufferLineGoToBuffer -1<cr>", desc = "Goto Last Buffer" },
    },
    opts = {
      options = {
        separator_style = "slope",
      },
    },
  },

  -- https://github.com/aimuzov/LazyVimx/blob/a27d3439b9021d1215ce6471f59d801df32c18d4/lua/lazyvimx/extras/ui/panels/status-line.lua
  {
    "nvim-lualine/lualine.nvim",
    opts = function(_, opts)
      local function cond_always_hidden()
        return false
      end

      -- https://github.com/aimuzov/LazyVimx/blob/a27d3439b9021d1215ce6471f59d801df32c18d4/lua/lazyvimx/extras/hacks/lazyvim-lualine-pretty-path.lua
      local function pretty_path(o)
        return function(self)
          return LazyVim.lualine.pretty_path(o)(self):gsub("/", "󰿟")
        end
      end

      -- https://github.com/Matt-FTW/dotfiles/blob/b12af2bc28c89c7185c48d6b02fb532b6d8be45d/.config/nvim/lua/plugins/extras/ui/lualine-extended.lua
      local lsp = function()
        local buf_clients = vim.lsp.get_clients({ bufnr = 0 })
        if #buf_clients == 0 then
          return ""
        end
        return " "
      end

      local formatter = function()
        local formatters = require("conform").list_formatters(0)
        if #formatters == 0 then
          return ""
        end
        return "󰛖 "
      end

      local linter = function()
        local linters = require("lint").linters_by_ft[vim.bo.filetype]
        if #linters == 0 then
          return ""
        end
        return "󱉶 "
      end

      -- "" ┊ |          
      -- opts.options.section_separators = { left = "", right = "" }
      -- opts.options.component_separators = { left = "", right = "" }
      opts.options.section_separators = { left = "", right = "" }
      opts.options.component_separators = { left = "", right = "" }

      -- ~/.local/share/nvim/lazy/LazyVim/lua/lazyvim/plugins/ui.lua
      ---@diagnostic disable-next-line: assign-type-mismatch
      opts.sections.lualine_c[1] = LazyVim.lualine.root_dir({ cwd = true })
      opts.sections.lualine_c[3].cond = cond_always_hidden -- filetype
      opts.sections.lualine_c[4] = {
        pretty_path({
          relative = "root",
          directory_hl = "Conceal",
          length = 6,
        }),
      }
      table.insert(opts.sections.lualine_x, 2, lsp)
      table.insert(opts.sections.lualine_x, 2, formatter)
      table.insert(opts.sections.lualine_x, 2, linter)
      opts.sections.lualine_y = { "filetype" }

      local bubbles = true
      if bubbles then
        opts.sections.lualine_a = { { "mode", separator = { left = "" } } }
        opts.sections.lualine_z = {
          { "location", separator = { left = "" }, padding = { left = 1, right = 0 } },
          { "progress", separator = { right = "" } },
        }
      else
        opts.sections.lualine_z = {
          { "location", separator = " ", padding = { left = 1, right = 0 } },
          { "progress", padding = { left = 0, right = 1 } },
        }
      end

      table.insert(opts.extensions, "mason")
    end,
  },

  -- https://github.com/folke/dot/blob/master/nvim/lua/plugins/ui.lua
  {
    "folke/twilight.nvim",
    cmd = "Twilight",
    opts = {
      context = 20, -- default value: 10
    },
  },
  {
    "folke/zen-mode.nvim",
    cmd = "ZenMode",
    keys = {
      { "<leader>z", "<cmd>ZenMode<cr>", desc = "Zen Mode" },
      {
        "<leader>Z",
        function()
          require("zen-mode").toggle({ plugins = { twilight = { enabled = true } } })
        end,
        desc = "Zen Mode (Twilight)",
      },
    },
    opts = function()
      local opts = {
        window = { backdrop = 0.7 },
        plugins = {
          gitsigns = true,
          tmux = true,
          neovide = { enabled = true, scale = 1 },
          kitty = { enabled = false, font = "+2" },
          alacritty = { enabled = false, font = "14" },
          twilight = { enabled = false },
        },
        -- https://github.com/bleek42/dev-env-config-backup/blob/099eb0c4468a03bcafb6c010271818fe8a794816/src/Linux/config/nvim/lua/user/plugins/editor.lua#L27
        on_open = function()
          vim.g.user_minianimate_disable_old = vim.g.minianimate_disable
          vim.g.minianimate_disable = true
        end,
        on_close = function()
          vim.g.minianimate_disable = vim.g.user_minianimate_disable_old
        end,
      }
      if not vim.env.TMUX then
        return opts
      end

      -- https://github.com/folke/zen-mode.nvim/blob/a31cf7113db34646ca320f8c2df22cf1fbfc6f2a/lua/zen-mode/plugins.lua#L96
      local function get_tmux_opt(option)
        local option_raw = vim.fn.system([[tmux show -w ]] .. option)
        if option_raw == "" then
          option_raw = vim.fn.system([[tmux show -g ]] .. option)
        end
        local opt = vim.split(vim.trim(option_raw), " ")[2]
        return opt
      end
      local tmux_status = get_tmux_opt("status")
      local group = vim.api.nvim_create_augroup("zen_mode_tmux", { clear = true })
      -- https://github.com/TranThangBin/init.lua/blob/3a357269ecbcb88d2a8b727cb1820541194f3283/lua/tranquangthang/lazy/zen-mode.lua#L39
      local on_open = opts.on_open or function() end
      opts.on_open = function()
        on_open()
        vim.g.user_zenmode_on = true
        -- restore tmux status line when switching to another tmux window or ctrl-z
        vim.api.nvim_create_autocmd({ "FocusLost", "VimSuspend" }, {
          group = group,
          desc = "Restore tmux status line on Neovim Focus Lost",
          callback = function()
            vim.fn.system(string.format([[tmux set status %s]], tmux_status))
          end,
        })
        vim.api.nvim_create_autocmd({ "FocusGained", "VimResume" }, {
          group = group,
          desc = "Hide tmux status line on Neovim Focus Gained",
          callback = function()
            vim.fn.system([[tmux set status off]])
          end,
        })
      end
      local on_close = opts.on_close or function() end
      opts.on_close = function()
        on_close()
        vim.g.user_zenmode_on = false
        vim.api.nvim_clear_autocmds({ group = group })
      end
      return opts
    end,
    config = function(_, opts)
      require("zen-mode").setup(opts)
      if vim.env.TMUX then
        -- https://github.com/folke/zen-mode.nvim/issues/111
        vim.api.nvim_create_autocmd({ "VimLeavePre" }, {
          desc = "Restore tmux status line when close Neovim in Zen Mode",
          callback = function()
            if vim.g.user_zenmode_on then
              require("zen-mode").close()
            end
          end,
        })
      end
    end,
  },

  -- {
  --   "shortcuts/no-neck-pain.nvim",
  --   opts = {
  --     width = 120, -- same width as zen-mode.nvim, default value: 100
  --   },
  --   keys = {
  --     { "<leader>uz", "<cmd>NoNeckPain<cr>", desc = "No Neck Pain" },
  --     { "<leader>uZ", ":NoNeckPainResize ", desc = "Resize the No-Neck-Pain window" },
  --   },
  -- },

  {
    "tzachar/highlight-undo.nvim",
    event = "VeryLazy",
    vscode = true,
    opts = function()
      -- link: Search IncSearch Substitute
      vim.api.nvim_set_hl(0, "HighlightUndo", { default = true, link = "Substitute" })
      vim.api.nvim_set_hl(0, "HighlightRedo", { default = true, link = "HighlightUndo" })
      return {
        --[[add custom config here]]
      }
    end,
  },
}
