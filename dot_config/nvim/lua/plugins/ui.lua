return {
  -- :h bufferline-configuration
  {
    "akinsho/bufferline.nvim",
    keys = function(_, keys)
      local mappings = {
        { "<Up>", "<cmd>BufferLineCyclePrev<cr>", desc = "Prev Buffer" },
        { "<Down>", "<cmd>BufferLineCycleNext<cr>", desc = "Next Buffer" },
        { "gj", "<cmd>BufferLineCycleNext<cr>", desc = "Next Buffer" },
        { "gk", "<cmd>BufferLineCyclePrev<cr>", desc = "Prev Buffer" },
        { "<leader>bH", "<cmd>BufferLineGoToBuffer 1<cr>", desc = "Goto First Buffer" },
        { "<leader>bL", "<cmd>BufferLineGoToBuffer -1<cr>", desc = "Goto Last Buffer" },
        { "<leader>bh", "<Cmd>BufferLineCloseLeft<CR>", desc = "Delete Buffers to the Left" },
        { "<leader>br", false },
        { "<leader>bl", "<Cmd>BufferLineCloseRight<CR>", desc = "Delete Buffers to the Right" },
      }
      -- for i = 1, 9 do
      --   table.insert(
      --     mappings,
      --     { "<leader>b" .. i, "<cmd>BufferLineGoToBuffer " .. i .. "<cr>", desc = "Goto Buffer " .. i }
      --   )
      -- end
      vim.list_extend(keys, mappings)
    end,
    opts = {
      options = {
        separator_style = "slant", -- slope
        offsets = {
          {
            filetype = "neo-tree",
            text = function()
              -- vim.fn.getcwd()
              local cwd = LazyVim.root.cwd()
              local root = LazyVim.root.get({ normalize = true })
              return cwd == root and "Explorer" or require("util.path").replace_home_with_tilde(cwd)
            end,
            highlight = "Directory",
            text_align = "left",
          },
        },
        -- hide extension
        name_formatter = function(buf)
          return buf.name:match("(.+)%..+$")
        end,
      },
    },
  },

  -- https://github.com/aimuzov/LazyVimx/blob/a27d3439b9021d1215ce6471f59d801df32c18d4/lua/lazyvimx/extras/ui/panels/status-line.lua
  -- https://github.com/jacquin236/minimal-nvim/blob/b74208114eae6cd724c276e0d966bf811822bcd5/lua/util/lualine.lua
  -- https://github.com/chrisgrieser/.config/blob/main/nvim/lua/plugins/lualine.lua
  -- https://github.com/barryblando/dotfiles/blob/078543ccb0be6c57284400c2a1b1af4a9dd46aa4/neovim/.config/nvim/lua/plugins/lualine.lua
  -- https://github.com/minusfive/dotfiles/blob/897c9596471854842cae52d774f7e43426287e58/.config/nvim/lua/plugins/ui.lua#L152
  {
    "nvim-lualine/lualine.nvim",
    opts = function(_, opts)
      -- local function hl_text(text, hl)
      --   return "%#" .. hl .. "#" .. text .. "%*"
      -- end

      local function ft_icon()
        -- require("mini.icons").get("file", vim.fn.expand("%:t"))
        local icon, hl, is_default = require("mini.icons").get("filetype", vim.bo.filetype) --[[@as string, string, boolean]]
        if not is_default then
          return icon .. " ", hl
        end
      end

      -- https://github.com/aimuzov/LazyVimx/blob/a27d3439b9021d1215ce6471f59d801df32c18d4/lua/lazyvimx/extras/hacks/lazyvim-lualine-pretty-path.lua
      local function pretty_path(o)
        return function(self)
          return LazyVim.lualine.pretty_path(o)(self):gsub("/", "󰿟")
        end
      end

      -- https://github.com/Matt-FTW/dotfiles/blob/b12af2bc28c89c7185c48d6b02fb532b6d8be45d/.config/nvim/lua/plugins/extras/ui/lualine-extended.lua
      local formatter = {
        function()
          return " " -- 󰛖 
        end,
        cond = function()
          local ok, conform = pcall(require, "conform")
          if not ok then
            return false
          end
          local formatters = conform.list_formatters(0)
          if #formatters > 0 then
            return true
          end
          local lsp_format = require("conform.lsp_format")
          local lsp_clients = lsp_format.get_format_clients({ bufnr = vim.api.nvim_get_current_buf() })
          return #lsp_clients > 0
        end,
        color = LazyVim.ui.fg("WhichKeyIconCyan"),
      }

      local linter = {
        function()
          return "󰁨 " -- 󱉶
        end,
        cond = function()
          local lint = require("lint")
          -- respect LazyVim extension `condition`
          -- see: ~/.local/share/nvim/lazy/LazyVim/lua/lazyvim/plugins/linting.lua
          local linters = lint._resolve_linter_by_ft(vim.bo.filetype)
          -- filter out linters that don't exist or don't match the condition
          local ctx = { filename = vim.api.nvim_buf_get_name(0) }
          ctx.dirname = vim.fn.fnamemodify(ctx.filename, ":h")
          linters = vim.tbl_filter(function(name)
            local l = lint.linters[name]
            return l and not (type(l) == "table" and l.condition and not l.condition(ctx))
          end, linters)
          return #linters > 0
        end,
        color = LazyVim.ui.fg("WhichKeyIconGreen"),
      }

      local lsp = {
        function()
          return ft_icon() or " " -- 
        end,
        cond = function()
          local clients = vim.lsp.get_clients({ bufnr = 0 })
          clients = vim.tbl_filter(function(client)
            local ignored = { "null-ls", "copilot" }
            return not vim.list_contains(ignored, client.name)
          end, clients)
          return #clients > 0
        end,
        color = function()
          return LazyVim.ui.fg(select(2, ft_icon()) or "Special") -- Identifier
        end,
      }

      local mode = { "mode" }
      if vim.g.user_is_termux then
        mode.fmt = function(str)
          return str:sub(1, 1)
        end
      end
      opts.sections.lualine_a = { mode }
      opts.sections.lualine_b = { { "branch", icons_enabled = not vim.g.user_is_termux } }

      -- see: ~/.local/share/nvim/lazy/LazyVim/lua/lazyvim/plugins/ui.lua
      local lualine_c = opts.sections.lualine_c
      lualine_c[1] = LazyVim.lualine.root_dir({ cwd = not vim.g.user_is_termux })
      if vim.g.user_is_termux or LazyVim.has("dropbar.nvim") then
        lualine_c[4] = {
          "filename",
          file_status = true,
          newfile_status = true, -- `nvim new_file`
          symbols = {
            modified = "",
            readonly = " 󰌾 ",
          },
          color = function()
            local fg
            if vim.bo.modified then
              fg = LazyVim.ui.color("MatchParen")
            elseif vim.bo.modifiable == false or vim.bo.readonly == true then
              fg = LazyVim.ui.color("DiagnosticError")
            end
            return { fg = fg, gui = "bold" }
          end,
        }
      else
        lualine_c[4] = {
          pretty_path({
            -- relative = "root",
            directory_hl = "Conceal",
          }),
        }
      end

      if not vim.g.user_is_termux then
        vim.list_extend(opts.sections.lualine_x, { formatter, linter, lsp })
      end

      opts.sections.lualine_y = {
        {
          "bo:filetype",
          cond = function()
            return not vim.g.user_is_termux
          end,
        },
        { "progress" },
      }

      -- "" ┊ |          
      -- nerdfont-powerline icons prefix: `ple-`
      opts.options.component_separators = { left = "", right = "" }

      local bubbles = false
      if bubbles then
        opts.options.section_separators = { left = "", right = "" }
        mode.separator = { left = "" }
        opts.sections.lualine_z = { { "location", separator = { right = "" } } }
      else
        opts.options.section_separators = { left = "", right = "" }
        opts.sections.lualine_z = { { "location" } }
      end

      table.insert(opts.extensions, "mason")
    end,
  },

  {
    "nvimdev/dashboard-nvim",
    optional = true,
    opts = function(_, opts)
      -- do not `startinsert` for "New File"
      local center = opts.config.center
      for _, button in ipairs(center) do
        if button.key == "n" then
          button.action = "ene"
          break
        end
      end

      -- https://github.com/nicknisi/dotfiles/blob/5ba5a46d2cb5fc6d6c9415300f04f57a20bb2f30/config/nvim/lua/nisi/assets.lua#L144
      opts.config.header = {
        [[                                                    ]],
        [[                                                    ]],
        [[                                                    ]],
        [[                                                    ]],
        [[                                                    ]],
        [[                                                    ]],
        [[                                                    ]],
        [[                                                    ]],
        [[ ███╗   ██╗███████╗ ██████╗ ██╗   ██╗██╗███╗   ███╗ ]],
        [[ ████╗  ██║██╔════╝██╔═══██╗██║   ██║██║████╗ ████║ ]],
        [[ ██╔██╗ ██║█████╗  ██║   ██║██║   ██║██║██╔████╔██║ ]],
        [[ ██║╚██╗██║██╔══╝  ██║   ██║╚██╗ ██╔╝██║██║╚██╔╝██║ ]],
        [[ ██║ ╚████║███████╗╚██████╔╝ ╚████╔╝ ██║██║ ╚═╝ ██║ ]],
        [[ ╚═╝  ╚═══╝╚══════╝ ╚═════╝   ╚═══╝  ╚═╝╚═╝     ╚═╝ ]],
        [[                                                    ]],
        [[                                                    ]],
      }

      -- remove some blank lines if the dashboard is too high
      local header = opts.config.header
      -- #opts.config.footer() == 1
      local invisible_lines = #header + #center * 2 + 1 - vim.o.lines + 1
      for i = #header - 2, 1, -1 do
        if invisible_lines <= 0 then
          break
        end
        if header[i]:match("^%s*$") then
          table.remove(header, i)
          invisible_lines = invisible_lines - 1
        end
      end
      for i = #header, #header - 1, -1 do
        if invisible_lines <= 0 then
          break
        end
        if header[i]:match("^%s*$") then
          table.remove(header, i)
          invisible_lines = invisible_lines - 1
        end
      end
    end,
  },

  {
    "echasnovski/mini.animate",
    optional = true,
    opts = function(_, opts)
      local animate = require("mini.animate")
      opts.cursor = {
        timing = animate.gen_timing.linear({ duration = 80, unit = "total" }),
        -- timing = animate.gen_timing.exponential({ easing = "out", duration = 80, unit = "total" }),
        -- path = animate.gen_path.line({
        --   predicate = function()
        --     return true
        --   end,
        -- }),
      }
      opts.scroll = {
        timing = animate.gen_timing.linear({ duration = 20, unit = "total" }),
      }
    end,
  },

  {
    "folke/edgy.nvim",
    optional = true,
    opts = function(_, opts)
      opts.animate = opts.animate or {}
      opts.animate.enabled = false

      for _, view in ipairs(opts.left or {}) do
        if view.ft == "neo-tree" then
          view.size = { width = 40 }
          view.title = "Neo-Tree"
          break
        end
      end

      for _, view in ipairs(opts.right or {}) do
        if view.ft == "dbui" and view.pinned then
          view.pinned = false
          break
        end
      end
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
          twilight = { enabled = false }, -- bad performance
        },
        -- https://github.com/bleek42/dev-env-config-backup/blob/099eb0c4468a03bcafb6c010271818fe8a794816/src/Linux/config/nvim/lua/user/plugins/editor.lua#L27
        on_open = function()
          vim.g.user_minianimate_disable_old = vim.g.minianimate_disable
          vim.g.minianimate_disable = true
          vim.g.user_winbar_old = vim.wo.winbar
          vim.wo.winbar = nil
        end,
        on_close = function()
          vim.g.minianimate_disable = vim.g.user_minianimate_disable_old
          vim.wo.winbar = vim.g.user_winbar_old
        end,
      }
      if not vim.env.TMUX then
        return opts
      end

      -- https://github.com/folke/zen-mode.nvim/issues/111
      vim.api.nvim_create_autocmd("VimLeavePre", {
        desc = "Restore tmux status line when close Neovim in Zen Mode",
        callback = function()
          if vim.g.user_zenmode_on then
            require("zen-mode").close()
          end
        end,
      })

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
      local group = vim.api.nvim_create_augroup("zenmode_tmux", { clear = true })
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
  },

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
