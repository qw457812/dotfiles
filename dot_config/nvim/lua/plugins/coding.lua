return {
  -- use helix-style mappings to prevent conflict with flash or leap: ms md mr
  -- https://www.reddit.com/r/neovim/comments/1bl3dwz/whats_your_best_remap_for_flash_or_leap/
  -- https://github.com/ggandor/leap.nvim/discussions/59
  -- or use kylechui/nvim-surround instead of mini.surround | https://github.com/boltlessengineer/nvim/blob/607ee0c9412be67ba127a4d50ee722be578b5d9f/lua/plugins/coding.lua#L95
  {
    "echasnovski/mini.surround",
    optional = true,
    opts = {
      mappings = {
        add = "ms",
        replace = "mr",
        delete = "md",
        find = "",
        find_left = "",
        highlight = "",
        update_n_lines = "m<C-n>",
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
        around_next = "",
        inside_next = "",
        around_last = "",
        inside_last = "",
        goto_left = "",
        goto_right = "",
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
        {
          "gx",
          function()
            require("various-textobjs").url()
            local foundURL = vim.fn.mode() == "v"
            if foundURL then
              local url = U.get_visual_selection()
              vim.ui.open(url)
              return
            end

            -- find all URLs in buffer
            local urlPatterns = require("various-textobjs.config").config.textobjs.url.patterns
            local bufText = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
            local urls = {}
            for _, urlPattern in ipairs(urlPatterns) do
              for url in bufText:gmatch(urlPattern) do
                table.insert(urls, url)
              end
            end
            if #urls == 0 then
              return
            end

            -- select one
            vim.ui.select(urls, { prompt = "Select URL:" }, function(choice)
              if choice then
                vim.ui.open(choice)
              end
            end)
          end,
          desc = "URL Opener",
        },
        {
          "mdi", -- mini.surround
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
        { name = "mdLink",               map = "l", desc = "md link [title](url)",   ft = { "markdown", "toml" } },
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

  -- https://github.com/yutkat/dotfiles/blob/a80b83c66c8e2b8fab68b32486a1a02afd3adddb/.config/nvim/lua/rc/pluginconfig/text-case.lua#L14
  {
    "johmsalas/text-case.nvim",
    enabled = false, -- using gregorias/coerce.nvim
    vscode = true,
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
    opts = {},
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
    "gregorias/coerce.nvim",
    keys = { { "ga", mode = { "n", "v" } } },
    ---@module 'coerce'
    ---@type CoerceConfigUser
    opts = {
      default_mode_keymap_prefixes = {
        normal_mode = "ga",
        visual_mode = "ga",
      },
      default_mode_mask = {
        motion_mode = false,
      },
    },
  },

  {
    "dmtrKovalenko/caps-word.nvim",
    keys = {
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
