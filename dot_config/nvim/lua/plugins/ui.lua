---@type LazySpec
return {
  -- icons
  {
    "LazyVim/LazyVim",
    ---@type LazyVimOptions|{}
    opts = {
      icons = {
        -- used in blink.cmp
        kinds = {
          Claude = "󰛄 ", --  
          OpenAI = " ", -- 󱥸 󰕖
          Gemini = " ", -- 󰫢
          Google = " ",
          Groq = " ",
          OpenRouter = "󰑪 ",
        },
      },
    },
  },
  {
    "folke/which-key.nvim",
    ---@module "which-key"
    ---@param opts wk.Opts
    opts = function(_, opts)
      local icons = LazyVim.config.icons.kinds
      return U.extend_tbl(opts, {
        icons = {
          rules = {
            { plugin = "CopilotChat.nvim", pattern = "copilot", icon = icons.Copilot, color = "azure" },
            { plugin = "claudecode.nvim", pattern = "claude", icon = icons.Claude, color = "orange" },
            { plugin = "codecompanion.nvim", pattern = "codecompanion", icon = " ", color = "purple" },
            { plugin = "mcphub.nvim", icon = " ", color = "grey" }, -- 
            { pattern = "sidekick", icon = " ", color = "green" },
            { pattern = "codex", icon = icons.OpenAI, color = "grey" },
            { pattern = "opencode", icon = "󰰕 ", color = "grey" }, -- 󰫼󰫰 
          } --[[@as wk.IconRule[] ]],
        },
      } --[[@as wk.Opts]])
    end,
  },
  {
    "nvim-mini/mini.icons",
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
        ["snacks_picker_input"] = { glyph = "󰏫", hl = "MiniIconsAzure" },
        ["snacks_picker_list"] = { glyph = "󰷐", hl = "MiniIconsAzure" },
        ["snacks_picker_preview"] = { glyph = "", hl = "MiniIconsAzure" },
        ["snacks_notif"] = { glyph = "󰎟", hl = "MiniIconsYellow" },
        ["noice"] = { glyph = "󰎟", hl = "MiniIconsYellow" },
        ["rip-substitute"] = { glyph = "", hl = "MiniIconsGreen" },
        ["sidekick_terminal"] = { glyph = "", hl = "MiniIconsGreen" },
      },
    },
  },

  {
    "akinsho/bufferline.nvim",
    optional = true,
    keys = function(_, keys)
      local mappings = {
        { "<Down>", "<cmd>BufferLineCycleNext<cr>", desc = "Next Buffer" },
        { "<Up>", "<cmd>BufferLineCyclePrev<cr>", desc = "Prev Buffer" },
        { "J", "<cmd>BufferLineCycleNext<cr>", desc = "Next Buffer" },
        { "K", "<cmd>BufferLineCyclePrev<cr>", desc = "Prev Buffer" },
        { "<leader>bH", "<cmd>lua require('bufferline').go_to(1, true)<cr>", desc = "Goto First Buffer" },
        { "<leader>bL", "<cmd>lua require('bufferline').go_to(-1, true)<cr>", desc = "Goto Last Buffer" },
        { "<leader>bh", "<Cmd>BufferLineCloseLeft<CR>", desc = "Delete Buffers to the Left" },
        { "<leader>br", false },
        { "<leader>bl", "<Cmd>BufferLineCloseRight<CR>", desc = "Delete Buffers to the Right" },
        { "<leader>ba", "<Cmd>BufferLineGroupClose ungrouped<CR>", desc = "Delete Non-Pinned Buffers" },
        {
          "<leader><tab>r",
          function()
            vim.ui.input({
              prompt = "New Tab Name: ",
              default = vim.fs.basename(LazyVim.root()),
            }, function(input)
              if input and input ~= "" then
                vim.cmd("BufferLineTabRename " .. input)
              end
            end)
            if vim.api.nvim_get_current_line() ~= "" then
              vim.cmd("stopinsert")
            end
          end,
          desc = "Rename Tab",
        },
      }
      for i = 1, 9 do
        table.insert(
          mappings,
          { "<leader>" .. i, "<cmd>BufferLineGoToBuffer " .. i .. "<cr>", desc = "which_key_ignore" }
        )
      end
      return vim.list_extend(keys, mappings)
    end,
    ---@param opts bufferline.UserConfig
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
                return o.raise(i)
              end
            end
            return o.raise(0)
          end,
          --- see: https://github.com/akinsho/bufferline.nvim/blob/28e347dbc6d0e8367ea56fb045fb9d135579ff79/lua/bufferline/models.lua#L182-L184
          ---@param buf {name: string, path: string, bufnr: integer}
          ---@return string?
          name_formatter = function(buf)
            local name = vim.b[buf.bufnr].user_bufferline_name
            if name then
              return name
            end
            -- hide extension unless it is a .env or docker-compose*.yml file
            local tail = vim.fn.fnamemodify(buf.name, ":t")
            return not (tail == ".env" or tail:match("^%.env%.") or tail:match("^docker%-compose.*%.yml$"))
                and buf.name:match("(.+)%..+$")
              or nil
          end,
          ---@param o bufferline.IconFetcherOpts
          get_element_icon = function(o)
            if vim.startswith(o.path, "jdt://") then
              return require("mini.icons").get("filetype", "javacc")
            end
            local icon, hl = get_element_icon(o)
            if icon then
              return icon, hl
            end
            return require("mini.icons").get(o.directory and "directory" or "file", o.path)
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
      } --[[@as bufferline.UserConfig]])
    end,
  },

  {
    "nvim-lualine/lualine.nvim",
    dependencies = { "nvim-mini/mini.icons" },
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

      opts.sections.lualine_a = {
        {
          "mode",
          fmt = is_termux and function(str)
            return str:sub(1, 1)
          end or nil,
        },
      }
      opts.sections.lualine_b = { { "branch", icons_enabled = not is_termux } }

      local lualine_c = opts.sections.lualine_c
      lualine_c[1] = LazyVim.lualine.root_dir({ cwd = not is_termux, icon = is_termux and "" or nil })
      lualine_c[4] = (is_termux or has_dropbar) and U.lualine.filename or U.lualine.pretty_path
      if is_termux then
        remove_component(lualine_c, "filetype")
      end
      if is_termux or has_dropbar or vim.g.trouble_lualine == false then
        local diagnostics = remove_component(lualine_c, "diagnostics")
        if not is_termux then
          table.insert(lualine_c, diagnostics)
        end
      end

      -- move copilot and sidekick to the right of command
      local lualine_x = opts.sections.lualine_x
      local copilot, sidekick = table.remove(lualine_x, 3), table.remove(lualine_x, 2)
      table.insert(lualine_x, 4, copilot)
      table.insert(lualine_x, 4, sidekick)
      if is_termux then
        remove_component(lualine_x, "diff")
      else
        vim.list_extend(lualine_x, { U.lualine.formatter, U.lualine.linter, U.lualine.lsp })
        table.insert(lualine_x, 2, U.lualine.wrap)
        table.insert(lualine_x, 2, U.lualine.hlsearch)
      end

      opts.sections.lualine_y = {
        {
          "bo:filetype",
          cond = function()
            return not is_termux
          end,
          color = function()
            -- align with https://github.com/qw457812/dotfiles/blob/424e2fa63c3f268cbf84453ba47d48f6f31e8293/dot_config/nvim/lua/util/lualine.lua#L55
            return vim.bo.buftype == "terminal" and vim.fn.mode():sub(1, 1) ~= "t" and { fg = "#FF007C" } or nil
          end,
        },
        { "progress" },
      }
      opts.sections.lualine_z = { { "location" } }

      -- "" ┊ |          
      -- nerdfont-powerline icons prefix: `ple-`
      opts.options.component_separators = { left = "", right = "" }

      local bubbles = false
      if bubbles then
        opts.options.section_separators = { left = "", right = "" }
        opts.sections.lualine_a[1].separator = { left = "" }
        opts.sections.lualine_z[#opts.sections.lualine_z].separator = { right = "" }
      elseif vim.g.user_is_termux then
        opts.options.section_separators = { left = "", right = "" }
      else
        opts.options.section_separators = { left = "", right = "" }
      end

      table.insert(opts.extensions, "mason")
    end,
  },

  {
    "folke/noice.nvim",
    optional = true,
    ---@module "noice"
    ---@param opts NoiceConfig
    opts = function(_, opts)
      if vim.g.deprecation_warnings then
        table.insert(opts.routes, {
          filter = {
            event = "msg_show",
            find = '.+ is deprecated%. Run ":checkhealth vim%.deprecated" for more information$',
          },
          view = "mini",
        })
      end

      return U.extend_tbl(opts, {
        -- presets = {
        --   bottom_search = false,
        -- },
        views = {
          cmdline_popup = {
            size = {
              min_width = math.min(60, math.floor(2 * vim.o.columns / 3)),
            },
          },
          -- split = {
          --   enter = true,
          --   size = "70%",
          --   win_options = {
          --     scrolloff = 4,
          --     sidescrolloff = 8,
          --   },
          -- },
        } --[[@as NoiceConfigViews]],
      } --[[@as NoiceConfig]])
    end,
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
    ---@module "snacks"
    ---@param opts snacks.Config
    opts = function(_, opts)
      local keys = opts.dashboard.preset.keys
      local lazy_idx, config_idx
      for i, key in ipairs(keys) do
        if key.key == "n" then
          key.action = ":ene" -- do not startinsert
        elseif key.key == "p" then
          key.key = "o" -- o for projects, p for paste
        elseif key.key == "s" and vim.g.user_auto_root then
          key.section, key.action = nil, ":lua require('persistence').load({ last = true })"
        elseif key.key == "q" then
          key.hidden = true
        elseif key.key == "l" then
          lazy_idx = i
        elseif key.key == "c" then
          config_idx = i
        end
      end
      -- stylua: ignore start
      table.insert(keys, (lazy_idx or #keys) + 1, { icon = "󱌢 ", key = "m", action = ":Mason", desc = "Mason" })
      table.insert(keys, (config_idx or #keys) + 1, { icon = "󰒲 ", key = ",", action = "<leader>f,", desc = "LazyVim Config" })
      table.insert(keys, 3, { icon = " ", key = "i", action = ":ene | startinsert", desc = "New File (Insert)", hidden = true })
      table.insert(keys, 4, { icon = " ", key = "a", action = ":ene | startinsert", desc = "New File (Append)", hidden = true })
      table.insert(keys, 5, { icon = " ", key = "p", action = ":ene | normal p", desc = "New File (Paste)", hidden = true })
      -- stylua: ignore end

      local headers = {
        nil, -- default header from snacks
        opts.dashboard.preset.header, -- default header from lazyvim
        [[
                                                                   
      ████ ██████           █████      ██                    
     ███████████             █████                            
     █████████ ███████████████████ ███   ███████████  
    █████████  ███    █████████████ █████ ██████████████  
   █████████ ██████████ █████████ █████ █████ ████ █████  
 ███████████ ███    ███ █████████ █████ █████ ████ █████ 
██████  █████████████████████ ████ █████ █████ ████ ██████]],
        [[
                                                           Z
      █████                      ████     ██         z  
     █████                        ████                   
     ███   ███ ███████████████████ ██  █████ 
    ███    ████     ██  ███████████ ███ ████████ 
   ███    ████   ██    ████████████ ███ ███ ██ ███ 
 █████████     ██ ██         ██ █████ ███ ███ ██ ███ 
███████████████████████████████  ███ ███ ███ ██ ███]],
      }
      local v = vim.version()
      opts.dashboard.preset.header = vim.g.user_is_termux and v and ("NVIM v%s.%s.%s"):format(v.major, v.minor, v.patch)
        or headers[math.random(#headers)]

      opts.dashboard.sections = {
        {}, -- top padding for header
        function() -- header
          if
            vim.g.user_is_termux
            or vim.fn.executable("npx") == 0
            or not (vim.uv.cwd() == U.path.HOME or Snacks.git.get_root()) -- frequently used dirs
          then
            return { section = "header" }
          end
          return {
            section = "terminal",
            -- npx -y oh-my-logo@latest "NEOVIM" --filled --letter-spacing 0 --gallery
            cmd = ('npx -y oh-my-logo@latest "NEOVIM" %s --filled --letter-spacing 0'):format(
              vim.startswith(vim.g.colors_name or "", "tokyonight") and "purple" or "nebula" -- random palettes?
            ),
            ttl = 3 * 24 * 60 * 60, -- cache for 3 days
            height = 10,
            indent = 5,
          } --[[@as snacks.dashboard.Item]]
        end,
        { section = "keys", padding = 1 },
        {
          icon = " ", --  
          title = "Recent Files",
          section = "recent_files",
          indent = 2,
          padding = 1,
          filter = function(file)
            return not file:match("COMMIT_EDITMSG$")
          end,
        },
        { icon = " ", title = "Projects", section = "projects", indent = 2, padding = 1 },
        { icon = " ", section = "startup" },
      }
    end,
  },

  {
    "nvim-mini/mini.animate",
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
    "nvim-mini/mini.indentscope",
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
