---@class util.rime_ls
local M = {}

-- copied from: https://github.com/Kaiser-Yang/dotfiles/blob/bdda941b06cce5c7505bc725f09dd3fa17763730/.config/nvim/lua/plugins/rime_ls.lua

local function contains_unacceptable_character(content)
  if content == nil then
    return true
  end
  local ignored_head_number = false
  for i = 1, #content do
    local b = string.byte(content, i)
    if b >= 48 and b <= 57 or b == 32 or b == 46 then
      -- number dot and space
      if ignored_head_number then
        return true
      end
    elseif b <= 127 then
      return true
    else
      ignored_head_number = true
    end
  end
  return false
end

M.lualine = {
  function()
    return "ㄓ"
  end,
  cond = function()
    return vim.g.rime_enabled
  end,
  color = function()
    return { fg = Snacks.util.color("MiniIconsRed") }
  end,
}

---@param item? blink.cmp.CompletionItem
---@return boolean
function M.is_valid_rime_item(item)
  if item == nil or item.source_name ~= "LSP" then
    return false
  end
  local client = vim.lsp.get_client_by_id(item.client_id)
  return client ~= nil and client.name == "rime_ls" and not contains_unacceptable_character(item.label)
end

---@param n integer
---@param items? blink.cmp.CompletionItem[]
---@return integer[]
function M.top_k_rime_item_indices(n, items)
  if items == nil then
    items = require("blink.cmp.completion.list").items
  end
  local res = {}
  if items == nil or #items == 0 then
    return res
  end
  for i, item in ipairs(items) do
    if M.is_valid_rime_item(item) then
      res[#res + 1] = i
      if #res == n then
        break
      end
    end
  end
  return res
end

---@param client vim.lsp.Client
function M.on_attach(client)
  local function toggle_rime()
    client.request("workspace/executeCommand", { command = "rime-ls.toggle-rime" }, function(_, result, ctx, _)
      if ctx.client_id == client.id then
        vim.g.rime_enabled = result
      end
    end)
  end
  vim.api.nvim_create_user_command("RimeToggle", toggle_rime, { desc = "Toggle Rime" })

  local max_code = 4
  local alphabet = "abcdefghijklmnopqrstuvwxyz"
  local reverse_lookup_prefix = "`"
  local mapped_punc = {
    [","] = "，",
    ["."] = "。",
    [";"] = "；",
    ["?"] = "？",
    ["\\"] = "、",
    -- [":"] = "：", -- disable it in favor of secondary election
  }

  -- auto accept when there is only one rime item after inputting a number
  require("blink.cmp.completion.list").show_emitter:on(function(event)
    if not vim.g.rime_enabled then
      return
    end
    local col = vim.fn.col(".") - 1
    if event.context.line:sub(col, col):match("%d") == nil then
      return
    end
    local rime_item_indices = U.rime_ls.top_k_rime_item_indices(2, event.items)
    if #rime_item_indices ~= 1 then
      return
    end
    require("blink.cmp").accept({ index = rime_item_indices[1] })
  end)

  -- toggle rime
  U.keymap({ "n", "i" }, "<c-.>", function()
    if vim.g.rime_enabled then
      for k, _ in pairs(mapped_punc) do
        vim.keymap.del("i", k .. "<space>")
      end
      for k in alphabet:gmatch(".") do
        vim.keymap.del("i", k)
      end
    else
      for k, v in pairs(mapped_punc) do
        U.keymap("i", k .. "<space>", v, { desc = "Chinese Punctuations [" .. v .. "] (Rime)" })
      end
      for k in alphabet:gmatch(".") do
        U.keymap("i", k, function()
          local confirmed = false
          local col = vim.api.nvim_win_get_cursor(0)[2]
          if col >= max_code then
            local content_before = vim.api.nvim_get_current_line():sub(1, col)
            local code = content_before:sub(col - max_code + 1, col)
            if
              code:match("^[" .. alphabet .. "]+$")
              and not content_before:match(reverse_lookup_prefix .. "[" .. alphabet .. "]*$")
            then
              local first_rime_item_indices = U.rime_ls.top_k_rime_item_indices(1)
              if #first_rime_item_indices ~= 1 then
                -- clear the wrong code
                for _ = 1, max_code do
                  vim.api.nvim_feedkeys(vim.keycode("<bs>"), "n", false)
                end
              else
                require("blink.cmp").accept({ index = first_rime_item_indices[1] })
                confirmed = true
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
        end, { desc = "Select first entry when typing more than max_code [" .. k .. "] (Rime)" })
      end
    end
    toggle_rime()
  end)
end

---@param opts? { filetypes?: string[] }
function M.setup(opts)
  assert(vim.fn.executable("rime_ls") == 1, "rime_ls is required")
  assert(LazyVim.has("blink.cmp"), "blink.cmp is required")

  vim.g.rime_enabled = false
  vim.system({ "rime_ls", "--listen", "127.0.0.1:9257" }, { detach = true })
  require("lspconfig.configs").rime_ls = {
    default_config = {
      name = "rime_ls",
      -- cmd = { "rime_ls" },
      cmd = vim.lsp.rpc.connect("127.0.0.1", 9257),
      filetypes = opts and opts.filetypes or { "*" },
      single_file_support = true,
    },
    settings = {},
    docs = {
      description = [[
https://github.com/wlh320/rime-ls

A language server for librime
]],
    },
  }

  -- HACK: rime_ls is visible in blink.cmp on startup
  LazyVim.lsp.on_attach(function()
    vim.defer_fn(function()
      vim.cmd("RimeToggle")
    end, 100)
    ---@diagnostic disable-next-line: redundant-return-value
    return true -- don't mess up toggle
  end, "rime_ls")
end

return M
