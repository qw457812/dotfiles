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
      local bar = require("dropbar.bar")
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
        DropBarFileName = { fg = Snacks.util.color("Normal"), bold = true },
        DropBarFileNameModified = { fg = Snacks.util.color("MatchParen"), bold = true },
        DropBarFolderName = { fg = Snacks.util.color("Conceal") },
        DropBarSymbolName = "DropBarFolderName",
      }, { default = true })

      -- local home_parts = vim.tbl_filter(function(part)
      --   return part ~= ""
      -- end, require("plenary.path"):new(home):_split())
      ---@diagnostic disable-next-line: param-type-mismatch
      local home_parts = vim.split(vim.uv.os_homedir(), "/", { trimempty = true })
      local source_path = {
        get_symbols = function(buff, win, cursor)
          local mini_icons = require("mini.icons")

          -- fix path for java library
          local jar, pkg, class = U.java.parse_jdt_uri(vim.api.nvim_buf_get_name(buff))
          if jar and pkg and class then
            local jar_icon = mini_icons.get("extension", "zip")
            local pkg_icon, pkg_icon_hl = mini_icons.get("lsp", "package")
            local class_icon, class_icon_hl = mini_icons.get("filetype", "javacc")
            return {
              bar.dropbar_symbol_t:new({
                icon = jar_icon .. " ",
                icon_hl = "MiniIconsRed",
                name = jar,
                name_hl = "DropBarFolderName",
              }),
              bar.dropbar_symbol_t:new({
                icon = pkg_icon .. " ",
                icon_hl = pkg_icon_hl,
                name = pkg,
                name_hl = "DropBarFolderName",
              }),
              bar.dropbar_symbol_t:new({
                icon = class_icon .. " ",
                icon_hl = class_icon_hl,
                name = class .. ".class",
                name_hl = "DropBarFileName",
              }),
            }
          end

          -- original symbols
          local symbols = sources.path.get_symbols(buff, win, cursor)
          if vim.tbl_isempty(symbols) then
            return symbols
          end

          -- filename highlighting
          for i = 1, #symbols - 1 do
            symbols[i].name_hl = "DropBarFolderName"
          end
          symbols[#symbols].name_hl = vim.bo[buff].modified and "DropBarFileNameModified" or "DropBarFileName"

          -- replace home dir with ~
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
            local home_icon, home_icon_hl = mini_icons.get("directory", "home")
            local symbol_home = symbols[#home_parts]
            symbol_home.name = "~"
            symbol_home.icon = home_icon .. " "
            symbol_home.icon_hl = home_icon_hl
            for i = #home_parts - 1, 1, -1 do
              table.remove(symbols, i)
            end
          end

          -- same behavior as `length` of `LazyVim.lualine.pretty_path()`
          local max_symbols = vim.g.user_is_termux and 5 or 10
          if #symbols > max_symbols then
            local symbol_ellipsis = symbols[2]
            symbol_ellipsis.name = "…"
            symbol_ellipsis.icon = ""
            symbols = { symbols[1], symbol_ellipsis, unpack(symbols, #symbols - max_symbols + 2, #symbols) }
          end

          local max_symbol_len = vim.g.user_is_termux and 10 or 18
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
              local icon, hl, is_default = require("mini.icons").get("file", path)
              if not is_default then
                return icon .. " ", hl
              end
              return dropbar_default_opts.icons.kinds.file_icon(path)
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
              -- -- show full path in oil buffers
              -- local bufname = vim.api.nvim_buf_get_name(buf)
              -- -- alternative: package.loaded["oil"] and require("oil.util").is_oil_bufnr(buf)
              -- if vim.startswith(bufname, "oil://") then
              --   local root = bufname:gsub("^%S+://", "", 1)
              --   while root and root ~= vim.fs.dirname(root) do
              --     root = vim.fs.dirname(root)
              --   end
              --   return root
              -- end
              if vim.bo[buf].filetype == "oil" then
                return "/"
              end

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
        return not is_unnamed_buffer()
          and (
            vim.bo.buflisted
            -- https://github.com/stevearc/oil.nvim/blob/09fa1d22f5edf0730824d2b222d726c8c81bbdc9/lua/oil/init.lua#L572
            -- alternative to vim.w.oil_preview: vim.wo.previewwindow
            or vim.bo.filetype == "oil" and not vim.w.oil_preview and vim.api.nvim_win_get_config(0).relative == ""
          )
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
