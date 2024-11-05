return {
  -- https://github.com/jacquin236/minimal-nvim/blob/8942639a07e2ac633c259be0386299a00cdef1be/lua/plugins/editor/dropbar.lua
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

      -- custom highlight
      -- stylua: ignore start
      vim.api.nvim_set_hl(0, "DropBarFileName", { default = true, fg = LazyVim.ui.color("DropBarKindFile"), bold = true })
      vim.api.nvim_set_hl(0, "DropBarFileNameModified", { default = true, fg = LazyVim.ui.color("MatchParen"), bold = true })
      vim.api.nvim_set_hl(0, "DropBarFolderName", { default = true, fg = LazyVim.ui.color("Conceal") })
      vim.api.nvim_set_hl(0, "DropBarSymbolName", { default = true, link = "DropBarFolderName" })
      -- stylua: ignore end

      -- local home_parts = vim.tbl_filter(function(part)
      --   return part ~= ""
      -- end, require("plenary.path"):new(home):_split())
      ---@diagnostic disable-next-line: param-type-mismatch
      local home_parts = vim.split(vim.uv.os_homedir(), "/", { trimempty = true })
      local source_path = {
        get_symbols = function(buff, win, cursor)
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
          local symbol_oil_prefix
          if vim.bo[buff].filetype == "oil" and symbols[1].name == "oil:" then
            symbol_oil_prefix = table.remove(symbols, 1)
          end
          local start_with_home = true
          for i, home_part in ipairs(home_parts) do
            if symbols[i].name ~= home_part then
              start_with_home = false
              break
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
          return symbols
        end,
      }

      local source_markdown = {
        get_symbols = function(buff, win, cursor)
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
          update_debounce = 20, -- performance for holding down `j`: 17 ~ 20
          sources = function(buf, _)
            if vim.bo[buf].ft == "markdown" then
              return { source_path, source_markdown }
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
            -- not necessary
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
            -- "%{%v:lua.dropbar.get_dropbar_str()%}",
            function()
              return dropbar.get_dropbar_str():gsub("%s%%%*$", "%%%*") -- remove last space in end_str, eval `vim.pesc(" %*")`
            end,
            cond = cond_winbar,
            padding = { left = 1, right = 0 },
          },
        },
      }

      -- for saecki/live-rename.nvim
      opts.inactive_winbar = vim.deepcopy(opts.winbar)

      if LazyVim.has("trouble.nvim") then
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
          -- max_items = 5,
        })
        table.insert(opts.winbar.lualine_c, {
          function()
            return symbols and symbols.get():gsub("%%%*%s%%#", "%%%*%%#") or "" -- remove sep spaces, eval `vim.pesc("%* %#")`
          end,
          cond = function()
            return cond_winbar() and vim.bo.ft ~= "markdown" and symbols.has()
          end,
          padding = { left = 0, right = 1 },
        })
      end
    end,
  },
}
