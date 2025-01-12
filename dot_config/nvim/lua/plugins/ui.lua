return {
  -- :h bufferline-configuration
  {
    "akinsho/bufferline.nvim",
    optional = true,
    keys = function(_, keys)
      local mappings = {
        { "<Down>", "<cmd>BufferLineCycleNext<cr>", desc = "Next Buffer" },
        { "<Up>", "<cmd>BufferLineCyclePrev<cr>", desc = "Prev Buffer" },
        { "J", "<cmd>BufferLineCycleNext<cr>", desc = "Next Buffer" },
        { "K", "<cmd>BufferLineCyclePrev<cr>", desc = "Prev Buffer" },
        { "<leader>bH", "<cmd>BufferLineGoToBuffer 1<cr>", desc = "Goto First Buffer" },
        { "<leader>bL", "<cmd>BufferLineGoToBuffer -1<cr>", desc = "Goto Last Buffer" },
        { "<leader>bh", "<Cmd>BufferLineCloseLeft<CR>", desc = "Delete Buffers to the Left" },
        { "<leader>br", false },
        { "<leader>bl", "<Cmd>BufferLineCloseRight<CR>", desc = "Delete Buffers to the Right" },
        { "<leader>ba", "<Cmd>BufferLineGroupClose ungrouped<CR>", desc = "Delete Non-Pinned Buffers" },
      }
      for i = 1, 9 do
        table.insert(
          mappings,
          { "<leader>b" .. i, "<cmd>BufferLineGoToBuffer " .. i .. "<cr>", desc = "Goto Buffer " .. i }
        )
      end
      vim.list_extend(keys, mappings)
    end,
    opts = function(_, opts)
      local get_element_icon = vim.tbl_get(opts, "options", "get_element_icon")
      get_element_icon = vim.is_callable(get_element_icon) and get_element_icon or function(_) end

      return U.extend_tbl(opts, {
        options = {
          -- indicator = { style = "underline" },
          separator_style = vim.g.user_transparent_background and { "", "" } or "slant", -- slope
          -- in favor of `BufferLineGoToBuffer`
          numbers = vim.g.user_is_termux and "none" or function(o)
            ---@type bufferline.State
            local state = require("bufferline.state")
            for i, item in ipairs(state.visible_components) do
              if item.id == o.id then
                -- return tostring(i)
                return o.raise(i)
              end
            end
            -- return "0"
            return o.raise(0)
          end,
          -- hide extension
          name_formatter = function(buf)
            local _, _, class = U.java.parse_jdt_uri(buf.path)
            return class or buf.name:match("(.+)%..+$")
          end,
          ---@param o bufferline.IconFetcherOpts
          get_element_icon = function(o)
            if vim.startswith(o.path, "jdt://") then
              return require("mini.icons").get("filetype", "javacc")
            end
            return get_element_icon(o)
          end,
          show_buffer_close_icons = false,
          show_close_icon = false,
          diagnostics = false,
          groups = {
            items = {
              require("bufferline.groups").builtin.pinned:with({ icon = "" }),
            },
          },
        },
      })
    end,
  },

  -- https://github.com/aimuzov/LazyVimx/blob/a27d3439b9021d1215ce6471f59d801df32c18d4/lua/lazyvimx/extras/ui/panels/status-line.lua
  -- https://github.com/chrisgrieser/.config/blob/main/nvim/lua/plugins/lualine.lua
  -- https://github.com/barryblando/dotfiles/blob/078543ccb0be6c57284400c2a1b1af4a9dd46aa4/neovim/.config/nvim/lua/plugins/lualine.lua
  -- https://github.com/minusfive/dotfiles/blob/897c9596471854842cae52d774f7e43426287e58/.config/nvim/lua/plugins/ui.lua#L152
  {
    "nvim-lualine/lualine.nvim",
    dependencies = { "echasnovski/mini.icons" },
    optional = true,
    opts = function(_, opts)
      local is_termux = vim.g.user_is_termux
      local has_dropbar = U.has_user_extra("ui.dropbar")

      local function remove_component(sections, comp_name)
        for i, comp in ipairs(sections) do
          if type(comp) == "table" and comp[1] == comp_name then
            return table.remove(sections, i)
          end
        end
      end

      -- -- https://github.com/Bekaboo/dropbar.nvim/blob/998441a88476af2ec77d8cb1b21bae62c9f548c1/lua/dropbar/utils/bar.lua#L11
      -- local function hl_str(str, hl)
      --   return "%#" .. hl .. "#" .. str .. "%*"
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
        color = { fg = Snacks.util.color("MiniIconsCyan") },
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
        color = { fg = Snacks.util.color("MiniIconsGreen") },
      }

      local lsp = {
        function()
          return ft_icon() or " " -- 
        end,
        cond = function()
          local clients = vim.lsp.get_clients({ bufnr = 0 })
          clients = vim.tbl_filter(function(client)
            local ignored = { "null-ls", "copilot", "rime_ls" }
            return not vim.list_contains(ignored, client.name)
          end, clients)
          return #clients > 0
        end,
        color = function()
          return { fg = Snacks.util.color(select(2, ft_icon()) or "Special") } -- Identifier
        end,
      }

      local hlsearch = {
        function()
          return "󱩾 " -- 󱎸 󰺯 󰺮
        end,
        cond = function()
          return vim.v.hlsearch == 1
        end,
        color = function()
          return { fg = Snacks.util.color("CurSearch", "bg") }
        end,
      }

      local wrap = {
        function()
          return "󰖶 " -- 
        end,
        cond = function()
          return vim.wo.wrap
        end,
        color = function()
          return { fg = Snacks.util.color("MiniIconsYellow") }
        end,
      }

      local mode = { "mode" }
      if is_termux then
        mode.fmt = function(str)
          return str:sub(1, 1)
        end
      end
      opts.sections.lualine_a = { mode }
      opts.sections.lualine_b = { { "branch", icons_enabled = not is_termux } }

      local lualine_c = opts.sections.lualine_c
      lualine_c[1] = LazyVim.lualine.root_dir({ cwd = not is_termux, icon = is_termux and "" or nil })
      lualine_c[4] = (is_termux or has_dropbar)
          and {
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
                fg = Snacks.util.color("MatchParen")
              elseif vim.bo.modifiable == false or vim.bo.readonly == true then
                fg = Snacks.util.color("DiagnosticError")
              end
              return { fg = fg, gui = "bold" }
            end,
            fmt = function(name, context)
              local _, _, class = U.java.parse_jdt_uri(vim.api.nvim_buf_get_name(0))
              return class and ("%s.class %s"):format(class, context.options.symbols.readonly) or name
            end,
          }
        or {
          pretty_path({
            relative = "root",
            directory_hl = "Conceal",
          }),
        }
      if is_termux then
        remove_component(lualine_c, "filetype")
      end
      if is_termux or has_dropbar or vim.g.trouble_lualine == false then
        local diagnostics = remove_component(lualine_c, "diagnostics")
        if not is_termux then
          table.insert(lualine_c, diagnostics)
        end
      end

      if is_termux then
        remove_component(opts.sections.lualine_x, "diff")
      else
        vim.list_extend(opts.sections.lualine_x, { formatter, linter, lsp })
        table.insert(opts.sections.lualine_x, 2, wrap)
        table.insert(opts.sections.lualine_x, 2, hlsearch)
      end

      opts.sections.lualine_y = {
        {
          "bo:filetype",
          cond = function()
            return not is_termux
          end,
        },
        { "progress" },
      }
      local location = { "location" }
      opts.sections.lualine_z = { location }

      -- "" ┊ |          
      -- nerdfont-powerline icons prefix: `ple-`
      opts.options.component_separators = { left = "", right = "" }

      local bubbles = false
      if bubbles then
        opts.options.section_separators = { left = "", right = "" }
        mode.separator = { left = "" }
        location.separator = { right = "" }
      else
        opts.options.section_separators = { left = "", right = "" }
      end

      table.insert(opts.extensions, "mason")
    end,
  },

  -- {
  --   "folke/noice.nvim",
  --   optional = true,
  --   opts = {
  --     presets = {
  --       bottom_search = false,
  --       -- command_palette = false,
  --     },
  --   },
  -- },

  {
    "echasnovski/mini.icons",
    optional = true,
    opts = {
      -- file = {
      --   -- ["init.lua"] = { glyph = "󰢱" }, -- see: #1384
      --   README = { glyph = "" },
      --   ["README.md"] = { glyph = "" },
      --   ["README.txt"] = { glyph = "" },
      -- },
      filetype = {
        -- plugin filetypes
        ["snacks_terminal"] = { glyph = "", hl = "MiniIconsCyan" },
        ["snacks_input"] = { glyph = "󰏫", hl = "MiniIconsAzure" },
        ["snacks_notif"] = { glyph = "󰎟", hl = "MiniIconsYellow" },
        ["noice"] = { glyph = "󰎟", hl = "MiniIconsYellow" },
        ["rip-substitute"] = { glyph = "", hl = "MiniIconsGreen" },
      },
    },
  },

  {
    "nvim-treesitter/nvim-treesitter-context",
    optional = true,
    opts = {
      multiwindow = true,
    },
  },

  {
    "nvimdev/dashboard-nvim",
    optional = true,
    opts = function(_, opts)
      -- do not `:startinsert` for "New File"
      local center = opts.config.center
      for _, button in ipairs(center) do
        if button.key == "n" then
          button.action = "ene"
          break
        end
      end

      -- opts.config.header = {
      --   [[                                                   ]],
      --   [[                                                   ]],
      --   [[                        ⢀ ⡠⢠ ⢂⢄⠂⠠⢄⡀⡀               ]],
      --   [[                     ⣀⢠⠒⠅⠨⢒ ⠧⢀ ⢃⠄ ⠤⠂⠐⠠             ]],
      --   [[                 ⢀ ⠲⠄⡂⠡⠐⠈⠁⠁⠒⠄ ⠂ ⠠ ⠉⠐ ⠅⠠⢁           ]],
      --   [[                ⠔⠌⠃⠄⢁⠐ ⠁⠁⠁  ⢈ ⠁ ⡀  ⡀   ⠄⠠          ]],
      --   [[             ⣀⢘⠉⡀⠂⡑⢈⠠⠐⠈     ⠄⠁        ⠠  ⠐         ]],
      --   [[            ⡐⠁⠂⠠⢀⠂⡀⠂      ⠐⠈ ⠐   ⡀       ⠅         ]],
      --   [[          ⠠⠈⠠⠁⠠⠁⡐⢐⡐     ⠐⠆⢀              ⠠         ]],
      --   [[          ⠌⡁⠐⢀ ⠡⢈⠬⣂⢀⠄⠄⠊⠂            ⠈    ⠂         ]],
      --   [[         ⠰ ⠄  ⠈ ⠐  ⠉  ⠐     ⠈          ⠂           ]],
      --   [[         ⠢  ⠈  ⠂  ⠁    ⢀       ⢀       ⢀⠄          ]],
      --   [[         ⠌ ⠂ ⢀    ⡀                                ]],
      --   [[         ⠠⢀              ⡀        ⠂                ]],
      --   [[             ⠠    ⢀                ⠆               ]],
      --   [[           ⠁               ⠄                       ]],
      --   [[              ⠈     ⠂       ⠐                      ]],
      --   [[                     ⠈                             ]],
      --   [[                                                   ]],
      --   [[                                                   ]],
      -- }

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
    "folke/snacks.nvim",
    optional = true,
    opts = function(_, opts)
      local keys = opts.dashboard.preset.keys
      local lazy_idx
      for i, key in ipairs(keys) do
        if key.key == "n" then
          key.action = ":ene" -- do not startinsert
        elseif key.key == "p" then
          key.key = "o" -- o for projects, p for paste
        elseif key.key == "c" and vim.g.user_is_termux then
          key.action = ":lua LazyVim.pick.config_files()()"
        elseif key.key == "s" and vim.g.user_auto_root then
          key.section = false
          key.action = ":lua require('persistence').load({ last = true })"
        elseif key.key == "q" then
          key.hidden = true
        elseif key.key == "l" then
          lazy_idx = i
        end
      end
      table.insert(keys, (lazy_idx or #keys) + 1, { icon = "󱌢 ", key = "m", action = ":Mason", desc = "Mason" })
      -- stylua: ignore start
      table.insert(keys, 3, { icon = " ", key = "i", action = ":ene | startinsert", desc = "New File (Insert)", hidden = true })
      table.insert(keys, 4, { icon = " ", key = "a", action = ":ene | startinsert", desc = "New File (Append)", hidden = true })
      table.insert(keys, 5, { icon = " ", key = "p", action = ":ene | normal p", desc = "New File (Paste)", hidden = true })
      -- stylua: ignore end

      opts.dashboard.preset.header = [[
  ⣴⣶⣤⡤⠦⣤⣀⣤⠆     ⣈⣭⣿⣶⣿⣦⣼⣆         
   ⠉⠻⢿⣿⠿⣿⣿⣶⣦⠤⠄⡠⢾⣿⣿⡿⠋⠉⠉⠻⣿⣿⡛⣦      
         ⠈⢿⣿⣟⠦ ⣾⣿⣿⣷    ⠻⠿⢿⣿⣧⣄    
          ⣸⣿⣿⢧ ⢻⠻⣿⣿⣷⣄⣀⠄⠢⣀⡀⠈⠙⠿⠄   
         ⢠⣿⣿⣿⠈    ⣻⣿⣿⣿⣿⣿⣿⣿⣛⣳⣤⣀⣀  
  ⢠⣧⣶⣥⡤⢄ ⣸⣿⣿⠘  ⢀⣴⣿⣿⡿⠛⣿⣿⣧⠈⢿⠿⠟⠛⠻⠿⠄ 
 ⣰⣿⣿⠛⠻⣿⣿⡦⢹⣿⣷   ⢊⣿⣿⡏  ⢸⣿⣿⡇ ⢀⣠⣄⣾⠄  
⣠⣿⠿⠛ ⢀⣿⣿⣷⠘⢿⣿⣦⡀ ⢸⢿⣿⣿⣄ ⣸⣿⣿⡇⣪⣿⡿⠿⣿⣷⡄ 
⠙⠃   ⣼⣿⡟  ⠈⠻⣿⣿⣦⣌⡇⠻⣿⣿⣷⣿⣿⣿ ⣿⣿⡇ ⠛⠻⢷⣄
     ⢻⣿⣿⣄   ⠈⠻⣿⣿⣿⣷⣿⣿⣿⣿⣿⡟ ⠫⢿⣿⡆    
      ⠻⣿⣿⣿⣿⣶⣶⣾⣿⣿⣿⣿⣿⣿⣿⣿⡟⢀⣀⣤⣾⡿⠃    ]]
      opts.dashboard.preset.header = [[
                                                                   
      ████ ██████           █████      ██                    
     ███████████             █████                            
     █████████ ███████████████████ ███   ███████████  
    █████████  ███    █████████████ █████ ██████████████  
   █████████ ██████████ █████████ █████ █████ ████ █████  
 ███████████ ███    ███ █████████ █████ █████ ████ █████ 
██████  █████████████████████ ████ █████ █████ ████ ██████]]
      local v = vim.version()
      opts.dashboard.preset.header = vim.g.user_is_termux and ("NVIM v%s.%s.%s"):format(v.major, v.minor, v.patch)
        or nil

      opts.dashboard.sections = {
        {}, -- top padding for header
        { section = "header" },
        -- { icon = " ", title = "Keymaps", section = "keys", indent = 2, padding = 1 },
        { section = "keys", padding = 1 },
        { icon = " ", title = "Recent Files", section = "recent_files", indent = 2, padding = 1 },
        { icon = " ", title = "Projects", section = "projects", indent = 2, padding = 1 },
        { icon = " ", section = "startup" },
      }
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
    "echasnovski/mini.indentscope",
    optional = true,
    opts = function()
      vim.api.nvim_create_autocmd("FileType", {
        pattern = {
          "rip-substitute",
          "dbui",
          "dbout",
          "harpoon",
          "leetcode.nvim",
          "Trans",
          "pantran",
        },
        callback = function()
          vim.b.miniindentscope_disable = true
        end,
      })
    end,
  },

  {
    "folke/edgy.nvim",
    optional = true,
    opts = {
      animate = {
        enabled = false,
      },
    },
  },
}
