local function has_words_before()
  local line, col = (unpack or table.unpack)(vim.api.nvim_win_get_cursor(0))
  return col ~= 0 and vim.api.nvim_buf_get_lines(0, line - 1, line, true)[1]:sub(col, col):match("%s") == nil
end

return {
  -- TODO: research
  -- https://github.com/hrsh7th/nvim-cmp/wiki/Example-mappings
  -- https://github.com/LazyVim/LazyVim/blob/330d2e470b79eb31f884685b331d5d255776de90/lua/lazyvim/plugins/compat/nvim-0_9.lua#L3
  -- https://github.com/LazyVim/LazyVim/blob/330d2e470b79eb31f884685b331d5d255776de90/lua/lazyvim/plugins/coding.lua#L109
  -- https://github.com/garymjr/nvim-snippets#installation
  -- https://github.com/LazyVim/LazyVim/blob/330d2e470b79eb31f884685b331d5d255776de90/lua/lazyvim/plugins/extras/coding/luasnip.lua#L41
  -- https://github.com/L3MON4D3/LuaSnip#keymaps
  -- https://github.com/LazyVim/LazyVim/issues/2533
  -- https://github.com/LazyVim/starter/commit/0c370f4d5c537e6d41dea31b547accc8d5f70a8a
  --
  -- https://www.lazyvim.org/configuration/recipes#supertab
  -- use <tab> for completion and snippets (supertab)
  {
    "hrsh7th/nvim-cmp",
    optional = true,
    ---@param opts cmp.ConfigSchema
    opts = function(_, opts)
      local cmp = require("cmp")

      opts.mapping = vim.tbl_extend("force", opts.mapping, {
        -- TODO: LazyVim.cmp.map
        ["<Tab>"] = cmp.mapping(function(fallback)
          if cmp.visible() then
            -- You could replace select_next_item() with confirm({ select = true }) to get VS Code autocompletion behavior
            cmp.select_next_item()
          elseif vim.snippet.active({ direction = 1 }) then
            vim.schedule(function()
              vim.snippet.jump(1)
            end)
          elseif has_words_before() then
            cmp.complete()
          else
            fallback()
          end
        end, { "i", "s" }),
        ["<S-Tab>"] = cmp.mapping(function(fallback)
          if cmp.visible() then
            cmp.select_prev_item()
          elseif vim.snippet.active({ direction = -1 }) then
            vim.schedule(function()
              vim.snippet.jump(-1)
            end)
          else
            fallback()
          end
        end, { "i", "s" }),
      })
    end,
  },
  -- nvim-cmp fork
  {
    "iguanacucumber/magazine.nvim",
    name = "nvim-cmp",
    optional = true,
    dependencies = {
      { "iguanacucumber/mag-nvim-lsp", name = "cmp-nvim-lsp", opts = {} },
      { "iguanacucumber/mag-nvim-lua", name = "cmp-nvim-lua" },
      { "iguanacucumber/mag-buffer", name = "cmp-buffer" },
      { "iguanacucumber/mag-cmdline", name = "cmp-cmdline" },
      { "https://codeberg.org/FelipeLema/cmp-async-path", name = "cmp-path" },
    },
  },

  {
    "saghen/blink.cmp",
    optional = true,
    opts = function(_, opts)
      -- copied from: https://github.com/AstroNvim/astrocommunity/blob/bb7988ac0efe0c17936c350c6da19051765f0e71/lua/astrocommunity/completion/blink-cmp/init.lua#L29
      opts.keymap = vim.tbl_extend("force", opts.keymap, {
        -- TODO: LazyVim.cmp.map
        ["<Tab>"] = {
          function(cmp)
            if cmp.windows.autocomplete.win:is_open() then
              return cmp.select_next()
            elseif cmp.is_in_snippet() then
              return cmp.snippet_forward()
            elseif has_words_before() then
              return cmp.show()
            end
          end,
          "fallback",
        },
        ["<S-Tab>"] = {
          function(cmp)
            if cmp.windows.autocomplete.win:is_open() then
              return cmp.select_prev()
            elseif cmp.is_in_snippet() then
              return cmp.snippet_backward()
            end
          end,
          "fallback",
        },
      })
    end,
  },

  -- use helix-style mappings to prevent conflict with flash or leap: ms md mr
  -- https://www.lazyvim.org/configuration/recipes#change-surround-mappings
  -- https://www.reddit.com/r/neovim/comments/1bl3dwz/whats_your_best_remap_for_flash_or_leap/
  -- https://github.com/ggandor/leap.nvim/discussions/59
  -- or use kylechui/nvim-surround instead of mini.surround | https://github.com/boltlessengineer/nvim/blob/607ee0c9412be67ba127a4d50ee722be578b5d9f/lua/plugins/coding.lua#L95
  {
    "echasnovski/mini.surround",
    optional = true,
    opts = {
      -- use `''` (empty string) to disable one.
      mappings = {
        -- gsa
        add = "ms", -- Add surrounding in Normal and Visual modes
        -- gsr
        replace = "mr", -- Replace surrounding
        -- gsd
        delete = "md", -- Delete surrounding
        -- gsf
        find = "", -- Find surrounding (to the right)
        -- gsF
        find_left = "", -- Find surrounding (to the left)
        -- gsh
        highlight = "", -- Highlight surrounding
        -- gsn
        update_n_lines = "m<C-n>", -- Update `n_lines`
      },
    },
  },
  {
    "folke/which-key.nvim",
    opts = {
      spec = {
        {
          mode = { "n", "v" },
          { "m", group = "match/surround" },
        },
      },
    },
  },

  {
    "echasnovski/mini.ai",
    optional = true,
    opts = {
      mappings = {
        -- next/last variants
        around_next = "", -- an
        inside_next = "", -- in
        around_last = "", -- al
        inside_last = "", -- il
        -- move cursor to corresponding edge of `a` textobject
        goto_left = "", -- g[
        goto_right = "", -- g]
      },
    },
  },

  {
    "gbprod/yanky.nvim",
    optional = true,
    keys = {
      { "gp", mode = { "n", "x" }, false },
      { "gP", mode = { "n", "x" }, false },
    },
  },

  {
    "Wansmer/treesj",
    vscode = true,
    keys = {
      { "<leader>J", "<cmd>TSJToggle<cr>", desc = "Join Toggle" },
    },
    opts = { use_default_keymaps = false, max_join_length = 150 },
  },

  {
    "chrisgrieser/nvim-various-textobjs",
    vscode = true,
    keys = function()
      local keys = {
        -- https://github.com/chrisgrieser/nvim-various-textobjs#smarter-gx
        {
          "gx",
          function()
            require("various-textobjs").url()
            local foundURL = vim.fn.mode():find("v")
            if foundURL then
              local url = U.get_visual_selection()
              vim.ui.open(url)
            else
              -- find all URLs in buffer
              local urlPattern = require("various-textobjs.charwise-textobjs").urlPattern
              local bufText = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
              local urls = {}
              for url in bufText:gmatch(urlPattern) do
                table.insert(urls, url)
              end
              if #urls == 0 then
                return
              end

              -- select one, use a plugin like dressing.nvim for nicer UI for `vim.ui.select`
              vim.ui.select(urls, { prompt = "Select URL:" }, function(choice)
                if choice then
                  vim.ui.open(choice)
                end
              end)
            end
          end,
          desc = "URL Opener",
        },
        -- https://github.com/chrisgrieser/nvim-various-textobjs#delete-surrounding-indentation
        {
          "mdi", -- :=LazyVim.opts("mini.surround").mappings.delete
          function()
            -- select outer indentation
            require("various-textobjs").indentation("outer", "outer")
            -- plugin only switches to visual mode when a textobj has been found
            local indentationFound = vim.fn.mode():find("V")
            if not indentationFound then
              return
            end

            -- dedent indentation
            vim.cmd.normal({ "<", bang = true })
            -- delete surrounding lines
            local endBorderLn = vim.api.nvim_buf_get_mark(0, ">")[1]
            local startBorderLn = vim.api.nvim_buf_get_mark(0, "<")[1]
            vim.cmd(tostring(endBorderLn) .. " delete") -- delete end first so line index is not shifted
            vim.cmd(tostring(startBorderLn) .. " delete")
          end,
          desc = "Delete Surrounding Indentation",
        },
        { "U", [[<cmd>lua require("various-textobjs").url()<CR>]], mode = { "o", "x" }, desc = "url" }, -- conflict with gUU
      }
      vim.keymap.set("n", "gUU", "gUU") -- prevent `omap U` from overwriting `gUU`

      -- stylua: ignore
      local ai_textobjs = {
        { name = "chainMember",          map = "m", desc = "chain member .foo(param)" }, -- map = "."
        { name = "key",                  map = "k", desc = "key-value, assignment" },
        { name = "value",                map = "v", desc = "key-value, assignment" },
        { name = "url",                  map = "l", desc = "url link" },
        -- markdown
        { name = "mdlink",               map = "l", desc = "md link [title](url)",   ft = { "markdown", "toml" } },
        { name = "mdFencedCodeBlock",    map = "C", desc = "md code block ```",      ft = "markdown" },
        { name = "mdEmphasis",           map = "E", desc = "md emphasis *_~=",       ft = "markdown" },
        -- python
        { name = "pyTripleQuotes",       map = "y", desc = [[py triple quotes """]], ft = "python" },
        -- lua, shell, org, neorg, markdown
        { name = "doubleSquareBrackets", map = "D", desc = "[[]] block",             ft = { "lua", "sh", "bash", "zsh", "fish", "org", "norg", "markdown" } },
        -- shell
        { name = "shellPipe",            map = "P", desc = "shell pipe |",           ft = { "sh", "bash", "zsh", "fish" } },
      }

      for _, tobj in ipairs(ai_textobjs) do
        -- stylua: ignore
        vim.list_extend(keys, {
          { "a" .. tobj.map, [[<cmd>lua require("various-textobjs").]] .. tobj.name .. [[("outer")<CR>]], mode = { "o", "x" }, desc = tobj.desc, ft = tobj.ft },
          { "i" .. tobj.map, [[<cmd>lua require("various-textobjs").]] .. tobj.name .. [[("inner")<CR>]], mode = { "o", "x" }, desc = tobj.desc, ft = tobj.ft },
        })
      end
      return keys
    end,
  },
  {
    "folke/which-key.nvim",
    opts = {
      spec = {
        { "gx", desc = "URL Opener" },
      },
    },
  },

  -- alternative: gregorias/coerce.nvim
  -- https://github.com/yutkat/dotfiles/blob/2c95d4f42752c5c245d7642f5c2dbc326bd776c2/.config/nvim/lua/rc/pluginconfig/text-case.lua
  {
    "johmsalas/text-case.nvim",
    -- event = "VeryLazy", -- for `Subs` and `substitude_command_name` command, with interactive feature on first use
    vscode = true,
    -- cmd = "S", -- for `substitude_command_name` command, without interactive feature on first use
    keys = function()
      local keys = {
        { "ga" },
        { "gar", ":Subs/", mode = { "n", "x" }, desc = "Subs" },
      }
      if LazyVim.has("telescope.nvim") or vim.g.vscode then
        keys[#keys + 1] = { "gaa", "<cmd>TextCaseOpenTelescope<CR>", mode = { "n", "x" }, desc = "Telescope" }
      end
      return keys
    end,
    opts = {
      -- -- an additional command with the passed in name will be created that does the same thing as "Subs" does
      -- substitude_command_name = "S",
    },
    config = function(_, opts)
      require("textcase").setup(opts)
      if LazyVim.has("telescope.nvim") then
        LazyVim.on_load("telescope.nvim", function()
          require("telescope").load_extension("textcase")
        end)
      end
    end,
  },

  {
    "dmtrKovalenko/caps-word.nvim",
    keys = {
      -- stylua: ignore
      { "<A-c>", "<cmd>lua require('caps-word').toggle()<CR>", mode = { "i", "n" }, desc = "Toggle Caps Word" },
    },
    opts = {
      enter_callback = function()
        vim.notify("Caps Word: On", "info", { title = "Caps Word" })
      end,
      exit_callback = function()
        vim.notify("Caps Word: Off", "info", { title = "Caps Word" })
      end,
    },
  },
}
