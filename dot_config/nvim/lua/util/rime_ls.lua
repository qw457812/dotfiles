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

M.cmp = {
  ---@param item? blink.cmp.CompletionItem
  ---@return boolean
  is_rime = function(item)
    if not item or item.source_name ~= "LSP" then
      return false
    end
    local client = vim.lsp.get_client_by_id(item.client_id)
    return client ~= nil and client.name == "rime_ls" and not contains_unacceptable_character(item.label)
  end,

  ---@param n integer
  ---@param items? blink.cmp.CompletionItem[]
  ---@return integer[]
  top_n_indices = function(n, items)
    items = items or require("blink.cmp").get_items()
    local res = {}
    for i, item in ipairs(items) do
      if M.cmp.is_rime(item) then
        res[#res + 1] = i
        if #res == n then
          break
        end
      end
    end
    return res
  end,

  ---@param n integer
  ---@return blink.cmp.KeymapCommand[]
  accept_n = function(n)
    return {
      ---@param cmp blink.cmp.API
      function(cmp)
        if not vim.g.rime_enabled then
          return
        end
        local indices = M.cmp.top_n_indices(n)
        if #indices ~= n then
          return
        end
        return cmp.accept({ index = indices[n] })
      end,
      "fallback",
    }
  end,

  ---@return blink.cmp.KeymapCommand[]
  esc_clear = function()
    return {
      ---@param cmp blink.cmp.API
      function(cmp)
        if not (vim.g.rime_enabled and cmp.is_visible()) then
          return
        end
        local items = require("blink.cmp").get_items()
        for _, item in ipairs(items) do
          if M.cmp.is_rime(item) then
            return item.textEdit
              and cmp.cancel({
                callback = function()
                  for _ = 1, item.textEdit.range["end"].character - item.textEdit.range.start.character do
                    vim.api.nvim_feedkeys(vim.keycode("<bs>"), "n", false)
                  end
                end,
              })
          end
        end
      end,
      "fallback",
    }
  end,

  ---@return blink.cmp.KeymapCommand[]
  enter_commit_code = function()
    return {
      ---@param cmp blink.cmp.API
      function(cmp)
        if not (vim.g.rime_enabled and cmp.is_visible()) then
          return
        end
        local items = require("blink.cmp").get_items()
        for _, item in ipairs(items) do
          if M.cmp.is_rime(item) then
            return cmp.cancel()
          end
        end
      end,
      "accept",
      "fallback",
    }
  end,
}

---@param enabled boolean
local function toggle_keymaps(enabled)
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

  if enabled then
    for k, v in pairs(mapped_punc) do
      U.keymap("i", k .. "<space>", v, { desc = "Chinese Punctuations [" .. v .. "] (Rime)" })
    end
    for k in alphabet:gmatch(".") do
      U.keymap("i", k, function()
        local accepted = false
        local col = vim.api.nvim_win_get_cursor(0)[2]
        if col >= max_code then
          local content_before = vim.api.nvim_get_current_line():sub(1, col)
          local code = content_before:sub(col - max_code + 1, col)
          if
            code:match("^[" .. alphabet .. "]+$")
            and not content_before:match(reverse_lookup_prefix .. "[" .. alphabet .. "]*$")
          then
            local indices = M.cmp.top_n_indices(1)
            if #indices ~= 1 then
              -- clear the wrong code
              for _ = 1, max_code do
                vim.api.nvim_feedkeys(vim.keycode("<bs>"), "n", false)
              end
            else
              require("blink.cmp").accept({ index = indices[1] })
              accepted = true
            end
          end
        end
        if accepted then
          vim.schedule(function()
            vim.api.nvim_feedkeys(vim.keycode(k), "n", false)
          end)
        else
          vim.api.nvim_feedkeys(vim.keycode(k), "n", false)
        end
      end, { desc = "Select first entry when typing more than max_code [" .. k .. "] (Rime)" })
    end
  else
    for k, _ in pairs(mapped_punc) do
      pcall(vim.keymap.del, "i", k .. "<space>")
    end
    for k in alphabet:gmatch(".") do
      pcall(vim.keymap.del, "i", k)
    end
  end
end

---@param client? vim.lsp.Client
function M.toggle(client)
  client = client or vim.lsp.get_clients({ name = "rime_ls", bufnr = 0 })[1]
  if not client or client.name ~= "rime_ls" then
    return
  end
  client.request("workspace/executeCommand", { command = "rime-ls.toggle-rime" }, function(_, res, ctx, _)
    if ctx.client_id ~= client.id or vim.g.rime_enabled == res then
      return
    end
    vim.g.rime_enabled = res
    toggle_keymaps(res)
    -- HACK: see: https://github.com/Saghen/blink.cmp/blob/cc2f10e9d8b6420324d4743a4d9a428de427e2cf/lua/blink/cmp/completion/accept/init.lua#L38
    require("blink.cmp.config").completion.accept.create_undo_point = not res
  end)
end

---@param client vim.lsp.Client
function M.on_attach(client)
  -- auto accept when there is only one rime item after inputting a number
  require("blink.cmp.completion.list").show_emitter:on(function(event)
    if not vim.g.rime_enabled then
      return
    end
    local col = vim.fn.col(".") - 1
    if event.context.line:sub(col, col):match("%d") == nil then
      return
    end
    local indices = M.cmp.top_n_indices(2, event.items)
    if #indices ~= 1 then
      return
    end
    require("blink.cmp").accept({ index = indices[1] })
  end)

  -- stylua: ignore
  U.keymap({ "n", "i" }, "<c-.>", function() M.toggle(client) end, { desc = "Toggle Rime" })
end

---@return boolean
function M.cond()
  return vim.fn.executable("rime_ls") == 1 and LazyVim.has("blink.cmp")
end

---@param opts? { filetypes?: string[] }
function M.setup(opts)
  assert(M.cond(), "rime_ls and blink.cmp are required")

  vim.system({ "rime_ls", "--listen", "127.0.0.1:9257" }, { detach = true })

  -- add rime_ls to lspconfig as a custom server
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
end

return M
