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
    ---@param opts cmp.ConfigSchema
    opts = function(_, opts)
      local has_words_before = function()
        unpack = unpack or table.unpack
        local line, col = unpack(vim.api.nvim_win_get_cursor(0))
        return col ~= 0 and vim.api.nvim_buf_get_lines(0, line - 1, line, true)[1]:sub(col, col):match("%s") == nil
      end

      local cmp = require("cmp")

      opts.mapping = vim.tbl_extend("force", opts.mapping, {
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

  -- https://github.com/folke/dot/blob/master/nvim/lua/plugins/coding.lua
  {
    "zbirenbaum/copilot.lua",
    optional = true,
    opts = {
      filetypes = { ["*"] = true },
    },
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

  -- alternative: gregorias/coerce.nvim
  -- https://github.com/yutkat/dotfiles/blob/2c95d4f42752c5c245d7642f5c2dbc326bd776c2/.config/nvim/lua/rc/pluginconfig/text-case.lua
  {
    "johmsalas/text-case.nvim",
    event = "VeryLazy", -- for `Subs` and `substitude_command_name` command, with interactive feature on first use
    vscode = true,
    cmd = "S", -- for `substitude_command_name` command, without interactive feature on first use
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
      -- an additional command with the passed in name will be created that does the same thing as "Subs" does
      substitude_command_name = "S",
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
    lazy = true,
    keys = {
      {
        mode = { "i", "n" },
        "<A-c>",
        "<cmd>lua require('caps-word').toggle()<CR>",
      },
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
