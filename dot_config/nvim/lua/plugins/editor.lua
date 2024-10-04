return {
  {
    "MagicDuck/grug-far.nvim",
    optional = true,
    keys = {
      {
        "<leader>sf",
        function()
          require("grug-far").open({
            transient = true,
            prefills = {
              paths = vim.fn.expand("%"),
              -- https://vi.stackexchange.com/questions/17465/how-to-search-literally-without-any-regex-pattern
              flags = "--fixed-strings",
              search = vim.fn.expand("<cword>"),
            },
            minSearchChars = 1,
          })
        end,
        mode = { "n", "v" },
        desc = "Search and Replace in Current File",
      },
    },
    opts = function()
      -- https://github.com/MagicDuck/grug-far.nvim#create-a-buffer-local-keybinding-to-toggle---fixed-strings-flag
      vim.api.nvim_create_autocmd("FileType", {
        pattern = "grug-far",
        callback = function()
          vim.keymap.set("n", "<localleader>w", function()
            local state = unpack(require("grug-far").toggle_flags({ "--fixed-strings" }))
            LazyVim.info(("Toggled `--fixed-strings`: **%s**"):format(state and "ON" or "OFF"), { title = "Grug Far" })
          end, { buffer = true, desc = "Grug Far: Toggle --fixed-strings" })
        end,
      })
    end,
  },

  {
    "folke/flash.nvim",
    optional = true,
    keys = function(_, keys)
      -- https://github.com/JoseConseco/nvim_config/blob/23dbf5f8b9779d792643ab5274ebe8dabe79c0c0/lua/plugins.lua#L1049
      -- https://github.com/mfussenegger/nvim-treehopper
      ---@param skip_first_match? boolean
      local function treesitter(skip_first_match)
        ---@type Flash.State.Config
        local opts = { label = { rainbow = { enabled = true } } }
        if skip_first_match then
          ---@param matches Flash.Match.TS[]
          opts.filter = function(matches)
            -- before removing first match, match[n+1] should use previous match[n] label
            for i = #matches, 2, -1 do
              matches[i].label = matches[i - 1].label
            end
            -- remove first match, as it is same as word under cursor (not always) thus redundant with word motion
            table.remove(matches, 1)
            return matches
          end
        end
        require("flash").treesitter(opts)
      end

      -- https://github.com/chrisgrieser/.config/blob/88eb71f88528f1b5a20b66fd3dfc1f7bd42b408a/nvim/lua/config/keybindings.lua#L150
      vim.keymap.set("n", "guu", "guu") -- prevent `omap u` from overwriting `guu`
      -- stylua: ignore
      return vim.list_extend(keys, {
        { "S", mode = { "n", "o", "x" }, function() treesitter() end, desc = "Flash Treesitter" },
        { "u", mode = { "o", "x" }, function() treesitter(true) end, desc = "Flash Treesitter" }, -- unit textobject, conflict with `guu`
        -- {
        --   "R",
        --   mode = { "o", "x" },
        --   function()
        --     require("flash").treesitter_search({ label = { rainbow = { enabled = true } } })
        --   end,
        --   desc = "Treesitter Search",
        -- },
      })
    end,
  },

  -- {
  --   "folke/which-key.nvim",
  --   opts = {
  --     win = {
  --       no_overlap = false, -- don't allow the popup to overlap with the cursor
  --     },
  --   },
  -- },

  -- {
  --   "RRethy/vim-illuminate",
  --   optional = true,
  --   opts = function(_, opts)
  --     -- -- base on tokyonight-moon
  --     -- local illuminate = "#51576d"
  --     -- -- remove `default = true,` to override colorscheme's highlight group
  --     -- vim.api.nvim_set_hl(0, "IlluminatedWordText", { default = true, bg = "#3b4261" })
  --     -- vim.api.nvim_set_hl(0, "IlluminatedWordRead", { default = true, bg = illuminate })
  --     -- vim.api.nvim_set_hl(0, "IlluminatedWordWrite", { default = true, bg = illuminate, underline = true })
  --     opts.filetypes_denylist = vim.list_extend(opts.filetypes_denylist or { "dirbuf", "dirvish", "fugitive" }, {
  --       "lazy",
  --       "mason",
  --       "harpoon",
  --       "qf",
  --       "netrw",
  --       "neo-tree",
  --       "oil",
  --       "minifiles",
  --       "trouble",
  --       "notify",
  --       "TelescopePrompt",
  --     })
  --   end,
  -- },

  -- alternative: https://github.com/xzbdmw/nvimconfig/blob/0be9805dac4661803e17265b435060956daee757/lua/theme/dark.lua#L23
  {
    "LazyVim/LazyVim",
    dependencies = {
      { "debugloop/layers.nvim", opts = {} },
    },
    keys = {
      -- stylua: ignore
      { "M", function() PAGER_MODE:toggle() end, desc = "Pager Mode" },
    },
    opts = function()
      if vim.g.vscode then
        return
      end

      ---@diagnostic disable-next-line: undefined-global
      PAGER_MODE = Layers.mode.new()
      PAGER_MODE:auto_show_help()
      PAGER_MODE:keymaps({
        n = {
          { "u", "<C-u>", { desc = "Scroll Up" } },
          -- { "d", "<C-d>", { desc = "Scroll Down", nowait = true } },
          { "d", "<C-d>", { desc = "Scroll Down" } },
          -- stylua: ignore
          { "<esc>", function() PAGER_MODE:deactivate() end, { desc = "Exit" } },
        },
      })
      local orig_dd_keymap ---@type table<string,any>
      local orig_minianimate_disable ---@type boolean?
      PAGER_MODE:add_hook(function(active)
        if active then
          -- remove `dd` mapping, defined in ../config/keymaps.lua
          -- https://github.com/debugloop/layers.nvim/blob/67666f59a2dbe36a469766be6a4c484ae98c4895/lua/layers/map.lua#L52
          orig_dd_keymap = vim.fn.maparg("dd", "n", false, true) --[[@as table<string,any>]]
          if not vim.tbl_isempty(orig_dd_keymap) then
            vim.keymap.del("n", "dd")
          end
          -- disable mini.animate
          orig_minianimate_disable = vim.g.minianimate_disable
          vim.g.minianimate_disable = true
        else
          if not vim.tbl_isempty(orig_dd_keymap) then
            vim.fn.mapset(orig_dd_keymap)
          end
          vim.g.minianimate_disable = orig_minianimate_disable
        end
      end)
    end,
  },

  -- for escaping easily from insert mode
  {
    "max397574/better-escape.nvim",
    event = "VeryLazy",
    opts = {
      -- note: lazygit, fzf-lua use terminal mode, `jj` and `jk` make lazygit navigation harder
      default_mappings = false,
      mappings = {
        i = {
          j = {
            -- these can all also be functions
            k = "<Esc>",
            j = "<Esc>",
          },
          k = {
            j = "<Esc>",
          },
        },
        c = {
          j = {
            k = "<Esc>",
            j = "<Esc>",
          },
          k = {
            j = "<Esc>",
          },
        },
      },
    },
  },

  -- better `:substitute`
  {
    "chrisgrieser/nvim-rip-substitute",
    cmd = "RipSubstitute",
    keys = {
      {
        "<leader>sF",
        function()
          require("rip-substitute").sub()
        end,
        mode = { "n", "x" },
        desc = " rip substitute",
      },
    },
    -- opts = {
    --   popupWin = {
    --     position = "top",
    --   },
    -- },
  },

  {
    "tzachar/highlight-undo.nvim",
    event = "VeryLazy",
    -- vscode = true,
    opts = function()
      -- link: Search IncSearch Substitute
      vim.api.nvim_set_hl(0, "HighlightUndo", { default = true, link = "Substitute" })
      vim.api.nvim_set_hl(0, "HighlightRedo", { default = true, link = "HighlightUndo" })
      return {
        keymaps = {
          paste = {
            disabled = true,
          },
          Paste = {
            disabled = true,
          },
        },
      }
    end,
  },

  -- TODO: choose motion plugin between: flash, leap, hop
  -- https://github.com/doctorfree/nvim-lazyman/blob/bb4091c962e646c5eb00a50eca4a86a2d43bcb7c/lua/ecovim/config/plugins.lua#L373
  -- "remote flash" for leap: https://github.com/rasulomaroff/telepath.nvim
}
