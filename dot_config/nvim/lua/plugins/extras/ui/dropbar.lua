return {
  -- https://github.com/LazyVim/LazyVim/pull/3503/files
  -- https://github.com/JuanZoran/myVimrc/blob/cc60c2a2d3ad51b4d6b34a187d85cbe0ce40ae45/lua/plugins/ui/extra/lualine.lua
  -- https://github.com/nghialm269/dotfiles/blob/26d814f697229cccdb01439e7a5c556f0539da47/nvim/.config/nvim/lua/plugins/ui.lua#L197
  {
    "Bekaboo/dropbar.nvim",
    event = "VeryLazy",
    dependencies = {
      "echasnovski/mini.icons",
      { "nvim-telescope/telescope-fzf-native.nvim", optional = true },
    },
    init = function()
      -- respect vim.g.trouble_lualine: whether to enable trouble document symbols in winbar.lualine_c
      vim.g.user_trouble_lualine_old = vim.g.trouble_lualine
      -- disable trouble document symbols in sections.lualine_c
      vim.g.trouble_lualine = false
    end,
    keys = {
      -- stylua: ignore
      { "<leader>wP", function() require("dropbar.api").pick() end, desc = "Winbar Pick" },
    },
    opts = function(_, opts)
      local sources = require("dropbar.sources")
      local menu_utils = require("dropbar.utils.menu")
      local dropbar_default_opts = require("dropbar.configs").opts

      -- https://github.com/MunifTanjim/nui.nvim/blob/HEAD/lua/nui/utils/init.lua#L206
      local function truncate_string(str, max_length)
        if #str <= max_length then
          return str
        end
        return str:sub(1, max_length - 1) .. "…"
      end

      -- custom highlight
      Snacks.util.set_hl({
        DropBarFileName = { fg = Snacks.util.color("DropBarKindFile"), bold = true },
        DropBarFileNameModified = { fg = Snacks.util.color("MatchParen"), bold = true },
        DropBarFolderName = { fg = Snacks.util.color("Conceal") },
        DropBarSymbolName = "DropBarFolderName",
      }, { default = true })

      -- local home_parts = vim.tbl_filter(function(part)
      --   return part ~= ""
      -- end, require("plenary.path"):new(home):_split())
      ---@diagnostic disable-next-line: param-type-mismatch
      local home_parts = vim.split(vim.uv.os_homedir(), "/", { trimempty = true })
      local oil_prefix = "oil:" -- oil.nvim
      -- local jdt_prefix = "jdt:" -- nvim-jdtls
      local source_path = {
        get_symbols = function(buff, win, cursor)
          local symbols = sources.path.get_symbols(buff, win, cursor)
          if vim.tbl_isempty(symbols) then
            return symbols
          end

          -- -- fix path for java library
          -- -- TODO: https://github.com/mfussenegger/nvim-jdtls/issues/423#issuecomment-1429184022
          -- if vim.bo[buff].filetype == "java" and #symbols > 1 and symbols[1].name == jdt_prefix then
          --   for i = #symbols, 2, -1 do
          --     if symbols[i].name:find("%.class%?=") then
          --       symbols[i].name = symbols[i].name:match("^(.+%.class)%?=")
          --       break
          --     else
          --       table.remove(symbols, i)
          --     end
          --   end
          -- end
          if vim.startswith(vim.api.nvim_buf_get_name(buff), "jdt://") then
            return {}
          end

          -- filename highlighting
          for i = 1, #symbols - 1 do
            symbols[i].name_hl = "DropBarFolderName"
          end
          symbols[#symbols].name_hl = vim.bo[buff].modified and "DropBarFileNameModified" or "DropBarFileName"

          -- replace home dir with ~
          local symbol_oil_prefix
          -- require("oil.util").is_oil_bufnr(buff)
          if vim.bo[buff].filetype == "oil" and #symbols > 1 and symbols[1].name == oil_prefix then
            symbol_oil_prefix = table.remove(symbols, 1)
          end
          local start_with_home = #symbols >= #home_parts
          if start_with_home then
            for i, home_part in ipairs(home_parts) do
              if symbols[i].name ~= home_part then
                start_with_home = false
                break
              end
            end
          end
          if start_with_home then
            local symbol_home = symbols[#home_parts]
            symbol_home.name = "~"
            local home_icon, home_icon_hl = require("mini.icons").get("directory", "home")
            symbol_home.icon = home_icon .. " "
            symbol_home.icon_hl = home_icon_hl
            for i = #home_parts - 1, 1, -1 do
              table.remove(symbols, i)
            end
          end
          if symbol_oil_prefix then
            table.insert(symbols, 1, symbol_oil_prefix)
          end

          -- same behavior as `length` of `LazyVim.lualine.pretty_path()`
          local max_symbols = vim.g.user_is_termux and 5 or 10
          if #symbols > max_symbols then
            local symbol_ellipsis = symbols[2]
            symbol_ellipsis.name = "…"
            symbol_ellipsis.icon = ""
            symbols = { symbols[1], symbol_ellipsis, unpack(symbols, #symbols - max_symbols + 2, #symbols) }
          end

          local max_symbol_len = vim.g.user_is_termux and 10 or 20
          for i = 2, #symbols - 1 do
            symbols[i].name = truncate_string(symbols[i].name, max_symbol_len)
          end

          return symbols
        end,
      }

      local source_markdown = {
        get_symbols = function(buff, win, cursor)
          if vim.b[buff].trouble_lualine == false then
            return {}
          end

          local symbols = sources.markdown.get_symbols(buff, win, cursor)
          for _, symbol in ipairs(symbols) do
            symbol.name_hl = "DropBarSymbolName"
          end
          return symbols
        end,
      }

      local function close()
        local menu = menu_utils.get_current()
        while menu and menu.prev_menu do
          menu = menu.prev_menu
        end
        if menu then
          menu:close()
        end
      end

      return vim.tbl_deep_extend("force", opts, {
        bar = {
          enable = false, -- using lualine.nvim
          -- update_debounce = 20, -- performance for holding down `j`: 17 ~ 20, commented out in favor of oil
          sources = function(buf, _)
            if vim.bo[buf].ft == "markdown" then
              return vim.g.user_trouble_lualine_old and { source_path, source_markdown } or { source_path }
            end
            if vim.bo[buf].buftype == "terminal" then
              return {}
            end
            return { source_path } -- using trouble.nvim's symbols instead, because it's shorter
          end,
        },
        icons = {
          kinds = {
            ---@type fun(path: string): string, string?|false
            dir_icon = function(path)
              local icon, hl, is_default = require("mini.icons").get("directory", path)
              if not is_default then
                return icon .. " ", hl
              end
              return dropbar_default_opts.icons.kinds.dir_icon(path)
            end,
            ---@type fun(path: string): string, string?|false
            file_icon = function(path)
              local default_file_icon = dropbar_default_opts.icons.kinds.file_icon
              local default_dir_icon = dropbar_default_opts.icons.kinds.dir_icon

              local function mini_icons_get(category, name, fallback)
                local icon, hl, is_default = require("mini.icons").get(category, name)
                if is_default and fallback then
                  return fallback(name)
                else
                  return icon .. " ", hl
                end
              end

              if path == oil_prefix then
                return mini_icons_get("filetype", "oil")
              -- elseif path == jdt_prefix then
              --   return mini_icons_get("filetype", "java")
              elseif vim.startswith(path, oil_prefix) then
                return mini_icons_get("directory", path:sub(#oil_prefix + 1), default_dir_icon)
              -- elseif vim.startswith(path, jdt_prefix) then
              --   path = path:sub(#jdt_prefix + 1):gsub("%?=.*$", "")
              --   if vim.endswith(path, ".jar") then
              --     return mini_icons_get("extension", "zip"), "MiniIconsRed"
              --   elseif vim.endswith(path, ".class") then
              --     return mini_icons_get("file", path, default_file_icon)
              --   else
              --     return mini_icons_get("directory", path, default_dir_icon)
              --   end
              else
                return mini_icons_get("file", path, default_file_icon)
              end
            end,
          },
        },
        menu = {
          keymaps = {
            ["q"] = close,
            ["<esc>"] = close,
            -- navigate back to the parent menu
            ["h"] = "<C-w>q",
            -- expands entry if possible
            ["l"] = function()
              local menu = menu_utils.get_current()
              if not menu then
                return
              end
              local cursor = vim.api.nvim_win_get_cursor(menu.win)
              local component = menu.entries[cursor[1]]:first_clickable(cursor[2])
              if component then
                menu:click_on(component, nil, 1, "l")
              end
            end,
            -- jump and close
            ["o"] = function()
              local menu = menu_utils.get_current()
              if not menu then
                return
              end
              local cursor = vim.api.nvim_win_get_cursor(menu.win)
              local entry = menu.entries[cursor[1]]
              local component = entry:first_clickable(entry.padding.left + entry.components[1]:bytewidth())
              if component then
                menu:click_on(component, nil, 1, "l")
              end
            end,
          },
        },
        sources = {
          path = {
            relative_to = function(buf, _)
              return LazyVim.root.get({ normalize = true, buf = buf })
            end,
          },
        },
      })
    end,
  },

  -- https://github.com/Bekaboo/dropbar.nvim/issues/19#issuecomment-1574760272
  {
    "nvim-lualine/lualine.nvim",
    dependencies = { "Bekaboo/dropbar.nvim" },
    opts = function(_, opts)
      local dropbar_default_opts = require("dropbar.configs").opts

      -- unsaved file by `:ene`
      local function is_unnamed_buffer()
        return vim.api.nvim_buf_get_name(0) == ""
      end

      -- disable winbar for unnamed or non-listed buffers
      local function cond_winbar()
        return not is_unnamed_buffer() and (vim.bo.buflisted or vim.bo.filetype == "oil")
      end

      opts.options.disabled_filetypes.winbar = vim.deepcopy(opts.options.disabled_filetypes.statusline)
      vim.list_extend(opts.options.disabled_filetypes.winbar, {
        "neo-tree",
        "minifiles",
        "yazi",
        "lazyterm",
        "noice",
        "trouble",
        "qf",
        "help",
        "man",
        "gitcommit",
        "grug-far",
      })

      opts.winbar = {
        lualine_c = {
          {
            -- "%{%v:lua.dropbar()%}",
            function()
              return dropbar():gsub("%s%%%*$", "%%%*") -- remove last space in end_str, eval `vim.pesc(" %*")`
            end,
            cond = cond_winbar,
            padding = { left = 1, right = 0 },
          },
        },
      }

      -- for saecki/live-rename.nvim
      opts.inactive_winbar = vim.deepcopy(opts.winbar)

      if not vim.g.user_is_termux and vim.g.user_trouble_lualine_old and LazyVim.has("trouble.nvim") then
        local trouble = require("trouble")
        local symbols = trouble.statusline({
          mode = "symbols", -- "lsp_document_symbols"
          groups = {},
          title = false,
          filter = { range = true },
          format = "{hl:DropBarIconUISeparator}"
            .. dropbar_default_opts.icons.ui.bar.separator
            .. "{hl}{kind_icon}{symbol.name:DropBarSymbolName}",
          -- hl_group = "lualine_c_normal",
          max_items = 5,
        })
        table.insert(opts.winbar.lualine_c, {
          function()
            return symbols and symbols.get():gsub("%%%*%s%%#", "%%%*%%#") or "" -- remove sep spaces, eval `vim.pesc("%* %#")`
          end,
          cond = function()
            return cond_winbar() and vim.bo.ft ~= "markdown" and vim.b.trouble_lualine ~= false and symbols.has()
          end,
          padding = { left = 0, right = 1 },
        })
      end
    end,
  },
}
