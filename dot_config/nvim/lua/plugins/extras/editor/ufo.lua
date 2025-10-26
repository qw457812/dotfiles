return {
  { "chrisgrieser/nvim-origami", optional = true, enabled = false },

  {
    "kevinhwang91/nvim-ufo",
    dependencies = {
      "kevinhwang91/promise-async",
      {
        "neovim/nvim-lspconfig",
        opts = {
          ---@type table<string, lazyvim.lsp.Config|boolean>
          servers = {
            ["*"] = {
              capabilities = {
                textDocument = {
                  foldingRange = {
                    dynamicRegistration = false,
                    lineFoldingOnly = true,
                  },
                },
              },
            },
          },
        },
      },
    },
    event = "VeryLazy",
    -- stylua: ignore
    keys = {
      { "zR", function() require("ufo").openAllFolds() end },
      { "zM", function() require("ufo").closeAllFolds() end },
      { "zr", function() require("ufo").openFoldsExceptKinds() end },
      { "zm", function() require("ufo").closeFoldsWith() end },
      { "z1", function() require("ufo").closeFoldsWith(1) end, desc = "Close L1 folds" },
      { "z2", function() require("ufo").closeFoldsWith(2) end, desc = "Close L2 folds" },
      { "z3", function() require("ufo").closeFoldsWith(3) end, desc = "Close L3 folds" },
      { "z4", function() require("ufo").closeFoldsWith(4) end, desc = "Close L4 folds" },
      { "<leader>iF", vim.cmd.UfoInspect, desc = "Fold" },
    },
    opts = function()
      -- -- kitty.conf
      -- vim.api.nvim_create_autocmd("BufReadPost", {
      --   callback = vim.schedule_wrap(function()
      --     if vim.wo.foldmethod == "marker" then
      --       require("ufo").closeAllFolds()
      --     end
      --   end),
      -- })

      -- add number suffix to folded lines
      local function virt_text_handler(virtText, lnum, endLnum, width, truncate)
        local newVirtText = {}
        local suffix = (" 󰘖 %d "):format(endLnum - lnum) -- ⋯ 
        local sufWidth = vim.fn.strdisplaywidth(suffix)
        local targetWidth = width - sufWidth
        local curWidth = 0
        for _, chunk in ipairs(virtText) do
          local chunkText = chunk[1]
          local chunkWidth = vim.fn.strdisplaywidth(chunkText)
          if targetWidth > curWidth + chunkWidth then
            table.insert(newVirtText, chunk)
          else
            chunkText = truncate(chunkText, targetWidth - curWidth)
            local hlGroup = chunk[2]
            table.insert(newVirtText, { chunkText, hlGroup })
            chunkWidth = vim.fn.strdisplaywidth(chunkText)
            -- string width returned from truncate() may be less than 2nd argument, need padding
            if curWidth + chunkWidth < targetWidth then
              suffix = suffix .. (" "):rep(targetWidth - curWidth - chunkWidth)
            end
            break
          end
          curWidth = curWidth + chunkWidth
        end
        table.insert(newVirtText, { suffix, "UfoFoldedEllipsis" })
        return newVirtText
      end

      --- (lsp -> treesitter -> indent) + marker
      ---@param bufnr number
      ---@return Promise
      local function selector(bufnr)
        local function handleFallbackException(err, providerName)
          if type(err) == "string" and err:match("UfoFallbackException") then
            return require("ufo").getFolds(bufnr, providerName)
          else
            return require("promise").reject(err)
          end
        end

        return require("ufo")
          .getFolds(bufnr, "lsp")
          :catch(function(err)
            -- snacks bigfile: lsp -> indent
            return U.is_bigfile(bufnr) and require("promise").reject(err) or handleFallbackException(err, "treesitter")
          end)
          :catch(function(err)
            return handleFallbackException(err, "indent")
          end)
          :thenCall(function(res)
            if U.is_bigfile(bufnr) then
              return res
            end
            -- alternative: require("ufo").getFolds(bufnr, "marker")
            -- NOTE: https://github.com/kevinhwang91/nvim-ufo/issues/233#issuecomment-2269229978
            -- PERF: https://github.com/kevinhwang91/nvim-ufo/issues/233#issuecomment-2226902851
            return res and vim.list_extend(res, require("ufo.provider.marker").getFolds(bufnr) or {})
          end, function(err)
            return require("promise").reject(err)
          end)
      end

      ---@type UfoConfig
      return {
        open_fold_hl_timeout = 150,
        -- enable_get_fold_virt_text = true, -- see: https://github.com/kevinhwang91/nvim-ufo/issues/26
        provider_selector = function(bufnr, filetype, buftype)
          -- see also: https://github.com/chrisgrieser/.config/blob/9a3fa5f42f6b402a0eb2468f38b0642bbbe7ccef/nvim/lua/plugin-specs/ufo.lua#L37-L42
          local ftMap = {
            vim = "indent",
            python = { "indent" },
            git = "",
          }
          return ftMap[filetype] or selector
        end,
        close_fold_kinds_for_ft = {
          default = {
            "imports",
            -- "comment",
            "marker",
          },
          -- json = { "array" },
          -- markdown = {}, -- prevent everything from being folded
          -- toml = {},
          gitcommit = {},
        },
        fold_virt_text_handler = virt_text_handler,
        preview = {
          win_config = {
            border = { "", "─", "", "", "", "─", "", "" },
            winblend = 0,
          },
          mappings = {
            scrollU = "<C-b>",
            scrollD = "<C-f>",
            jumpTop = "[",
            jumpBot = "]",
          },
        },
      }
    end,
  },

  {
    "kevinhwang91/nvim-ufo",
    keys = {
      {
        "gk",
        function()
          local ufo_preview_win = require("ufo").peekFoldedLinesUnderCursor()
          if ufo_preview_win then
            vim.bo[vim.api.nvim_win_get_buf(ufo_preview_win)].filetype = "ufo_preview" -- for augroup: pager_nomodifiable
          elseif U.lsp.has(0, "hover") then
            vim.lsp.buf.hover()
          else
            vim.cmd.normal({ "K", bang = true })
          end
        end,
        desc = "Peek Fold (UFO) / Hover / Keywordprg",
      },
    },
    ---@type UfoConfig
    opts = {
      preview = {
        mappings = {
          switch = "gk",
        },
      },
    },
  },
}
