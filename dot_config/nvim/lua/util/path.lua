---@class util.path
local M = {}

M.HOME = assert(vim.uv.os_homedir()) -- os.getenv("HOME")

-- function M.is_dir(path)
--   -- -- https://github.com/folke/snacks.nvim/pull/136#issuecomment-2492044614
--   -- return (vim.uv.fs_stat(path) or {}).type == "directory"
--   return vim.fn.isdirectory(path) == 1
-- end

-- function M.is_file(path)
--   -- -- https://github.com/neovim/nvim-lspconfig/pull/3495
--   -- return vim.fn.getftype(path) == "file"
--   return (vim.uv.fs_stat(path) or {}).type == "file"
-- end

--- Chezmoi source path
M.CHEZMOI = (function()
  local path = M.HOME .. "/.local/share/chezmoi"
  return vim.fn.isdirectory(path) == 1 and path or nil
end)()

M.CONFIG = (function()
  local has_chezmoi = M.CHEZMOI and LazyVim.has_extra("util.chezmoi") and vim.fn.executable("chezmoi") == 1
  return has_chezmoi and M.CHEZMOI .. "/dot_config/nvim" or vim.fn.stdpath("config") --[[@as string]]
end)()

-- require("lazy.core.config").options.root .. "/LazyVim"
M.LAZYVIM = LazyVim.get_plugin_path("LazyVim")

--- Replace home directory with '~'
--- https://github.com/echasnovski/mini.files/blob/10ed64157ec45f176decefbdb0e2ba10cccd187f/lua/mini/files.lua#L2365
--- https://github.com/ibhagwan/fzf-lua/blob/769b6636af07ea4587e6c06067d8fe9fb0629390/lua/fzf-lua/path.lua#L253
--- https://github.com/nvim-lualine/lualine.nvim/blob/b431d228b7bbcdaea818bdc3e25b8cdbe861f056/lua/lualine/extensions/nerdtree.lua#L4
---@param path string
---@return string
function M.home_to_tilde(path)
  -- vim.fn.fnamemodify(path, ":~")
  M._HOME_PATTERN = M._HOME_PATTERN or ("^" .. vim.pesc(M.HOME))
  return (path:gsub(M._HOME_PATTERN, "~"))
end

-- need to expand "~/" before calling this
---@param path string
---@return string
function M.relative_to_home(path)
  return require("plenary.path"):new(path):make_relative(M.HOME)
end

-- need to expand "~/" before calling this
---@param path string
---@return string
function M.relative_to_root(path)
  return require("plenary.path"):new(path):make_relative(LazyVim.root({ normalize = true }))
end

---@param path string
---@return string
function M.shorten(path)
  path = M.home_to_tilde(path)

  local dir_icons = { { M.CONFIG, " " }, { M.LAZYVIM, "󰒲 " } }
  if M.CHEZMOI then
    table.insert(dir_icons, { M.CHEZMOI, "󰠦 " })
  end
  for _, dir_icon in ipairs(dir_icons) do
    path = path:gsub("^" .. vim.pesc(M.home_to_tilde(dir_icon[1])) .. "/", dir_icon[2])
  end

  return U.java.path_shorten(path)
end

return M
