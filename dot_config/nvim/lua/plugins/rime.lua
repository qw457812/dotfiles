-- https://github.com/wlh320/rime-ls
if not (vim.fn.executable("rime_ls") == 1 and LazyVim.has("blink.cmp")) then
  return {}
end

local toggle_key = "<c-space>" -- TODO:

local function rime_on_attach(client, _)
  vim.api.nvim_create_user_command("RimeToggle", function()
    client.request("workspace/executeCommand", { command = "rime-ls.toggle-rime" }, function(_, result, ctx, _)
      if ctx.client_id == client.id then
        vim.g.rime_enabled = result
      end
    end)
  end, { nargs = 0 })

  local max_code = 4

  -- TODO: there is no 'z' in the alphabet
  local alphabet = "abcdefghijklmnopqrstuvwxy"
  local mapped_punc = {
    [","] = "，",
    ["."] = "。",
    [":"] = "：",
    ["?"] = "？",
    ["\\"] = "、",
    [";"] = "；",
  }

  local function match_alphabet(txt)
    return string.match(txt, "^[" .. alphabet .. "]+$") ~= nil
  end

  -- auto accept when there is only one rime item after inputting a number
  require("blink.cmp.completion.list").show_emitter:on(function(event)
    if not vim.g.rime_enabled then
      return
    end
    local col = vim.fn.col(".") - 1
    if event.context.line:sub(col, col):match("%d") == nil then
      return
    end
    local rime_item_index = U.rime_ls.get_n_rime_item_index(2, event.items)
    if #rime_item_index ~= 1 then
      return
    end
    require("blink.cmp").accept({ index = rime_item_index[1] })
  end)

  -- Toggle rime
  -- This will toggle Chinese punctuations too
  U.keymap({ "n", "i" }, toggle_key, function()
    -- We must check the status before the toggle
    if vim.g.rime_enabled then
      for k, _ in pairs(mapped_punc) do
        vim.keymap.del({ "i" }, k .. "<space>")
      end
    else
      for k, v in pairs(mapped_punc) do
        U.keymap({ "i" }, k .. "<space>", v)
      end
    end
    vim.cmd("RimeToggle")
  end)

  -- Select first entry when typing more than max_code
  for i = 1, #alphabet do
    local k = alphabet:sub(i, i)
    U.keymap({ "i" }, k, function()
      local cursor_column = vim.api.nvim_win_get_cursor(0)[2]
      local confirmed = false
      if vim.g.rime_enabled and cursor_column >= max_code then
        local content_before_cursor = string.sub(vim.api.nvim_get_current_line(), 1, cursor_column)
        local code = string.sub(content_before_cursor, cursor_column - max_code + 1, cursor_column)
        if match_alphabet(code) then
          -- TODO: This is for wubi users using 'z' as reverse look up
          if not string.match(content_before_cursor, "z[" .. alphabet .. "]*$") then
            local first_rime_item_index = U.rime_ls.get_n_rime_item_index(1)
            if #first_rime_item_index ~= 1 then
              -- clear the wrong code
              for _ = 1, max_code do
                vim.api.nvim_feedkeys(vim.keycode("<bs>"), "n", false)
              end
            else
              require("blink.cmp").accept({ index = first_rime_item_index[1] })
              confirmed = true
            end
          end
        end
      end
      if confirmed then
        vim.schedule(function()
          vim.api.nvim_feedkeys(vim.keycode(k), "n", false)
        end)
      else
        vim.api.nvim_feedkeys(vim.keycode(k), "n", false)
      end
    end)
  end
end

-- https://github.com/wlh320/rime-ls/blob/4986d4d765870846f689e1e06dc9baa2ac2aff34/doc/nvim-with-blink.md
-- https://github.com/Kaiser-Yang/dotfiles/tree/bdda941b06cce5c7505bc725f09dd3fa17763730
-- https://github.com/liubianshi/cmp-lsp-rimels/tree/blink.cmp
return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        rime_ls = {
          init_options = {
            enabled = vim.g.rime_enabled,
            shared_data_dir = "/Library/Input Methods/Squirrel.app/Contents/SharedSupport",
            user_data_dir = vim.fn.expand("~/.local/share/rime-ls"),
            log_dir = vim.fn.expand("~/.local/share/rime-ls"),
            max_tokens = 4,
            always_incomplete = true,
            long_filter_text = true,
          },
          on_attach = rime_on_attach,
        },
      },
      setup = {
        rime_ls = function()
          U.rime_ls.setup({
            filetype = vim.g.rime_ls_support_filetype,
          })
        end,
      },
    },
  },

  {
    "saghen/blink.cmp",
    optional = true,
    ---@module 'blink.cmp'
    ---@type blink.cmp.Config
    opts = {
      keymap = {
        ["<space>"] = {
          function(cmp)
            if not vim.g.rime_enabled then
              return false
            end
            local rime_item_index = U.rime_ls.get_n_rime_item_index(1)
            if #rime_item_index ~= 1 then
              return false
            end
            return cmp.accept({ index = rime_item_index[1] })
          end,
          "fallback",
        },
        [":"] = { -- TODO: not working
          function(cmp)
            if not vim.g.rime_enabled then
              return false
            end
            local rime_item_index = U.rime_ls.get_n_rime_item_index(2)
            if #rime_item_index ~= 2 then
              return false
            end
            return cmp.accept({ index = rime_item_index[2] })
          end,
          "fallback",
        },
        ["'"] = {
          function(cmp)
            if not vim.g.rime_enabled then
              return false
            end
            local rime_item_index = U.rime_ls.get_n_rime_item_index(3)
            if #rime_item_index ~= 3 then
              return false
            end
            return cmp.accept({ index = rime_item_index[3] })
          end,
          "fallback",
        },
      },
      sources = {
        providers = {
          lsp = {
            -- copied from: https://github.com/Saghen/blink.cmp/blob/00ad008cbea4d0d2b5880e7c7386caa9fc4e5e2b/lua/blink/cmp/config/sources.lua#L65
            transform_items = function(_, items)
              -- demote snippets
              for _, item in ipairs(items) do
                if item.kind == require("blink.cmp.types").CompletionItemKind.Snippet then
                  item.score_offset = item.score_offset - 3
                end
              end

              -- filter out text items, since we have the buffer source
              ---@param item blink.cmp.CompletionItem
              return vim.tbl_filter(function(item)
                return item.kind ~= require("blink.cmp.types").CompletionItemKind.Text or U.rime_ls.is_rime_item(item)
              end, items)
            end,
          },
        },
      },
    },
  },

  {
    "nvim-lualine/lualine.nvim",
    optional = true,
    opts = function(_, opts)
      table.insert(opts.sections.lualine_x, 2, U.rime_ls.lualine)
    end,
  },
}
