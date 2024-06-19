return {
  -- https://www.lazyvim.org/configuration/recipes#supertab
  -- use <tab> for completion and snippets
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
    opts = {
      filetypes = { ["*"] = true },
    },
  },

  -- use helix-style mappings to work with flash or leap: ms mr md
  -- https://www.lazyvim.org/configuration/recipes#change-surround-mappings
  -- https://www.reddit.com/r/neovim/comments/1bl3dwz/whats_your_best_remap_for_flash_or_leap/
  -- https://github.com/ggandor/leap.nvim/discussions/59
  -- or use kylechui/nvim-surround instead of mini.surround | https://github.com/boltlessengineer/nvim/blob/607ee0c9412be67ba127a4d50ee722be578b5d9f/lua/plugins/coding.lua#L95
  {
    "echasnovski/mini.surround",
    opts = {
      -- use `''` (empty string) to disable one.
      mappings = {
        -- gsa -> ms
        add = "ms", -- Add surrounding in Normal and Visual modes
        -- gsd -> md
        delete = "md", -- Delete surrounding
        find = "gsf", -- Find surrounding (to the right)
        find_left = "gsF", -- Find surrounding (to the left)
        highlight = "gsh", -- Highlight surrounding
        -- gsr -> mr
        replace = "mr", -- Replace surrounding
        update_n_lines = "gsn", -- Update `n_lines`
      },
    },
  },
}
