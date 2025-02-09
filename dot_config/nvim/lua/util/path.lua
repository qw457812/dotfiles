---@class util.path
local M = {}

function M.is_dir(path)
  -- -- https://github.com/folke/snacks.nvim/pull/136#issuecomment-2492044614
  -- return (vim.uv.fs_stat(path) or {}).type == "directory"
  return vim.fn.isdirectory(path) == 1
end

function M.is_file(path)
  -- -- https://github.com/neovim/nvim-lspconfig/pull/3495
  -- return vim.fn.getftype(path) == "file"
  return (vim.uv.fs_stat(path) or {}).type == "file"
end

-- os.getenv("HOME")
-- vim.fs.normalize("~")
M.HOME = assert(vim.uv.os_homedir())

--- Chezmoi source path
M.CHEZMOI = (function()
  if not (LazyVim.has_extra("util.chezmoi") and vim.fn.executable("chezmoi") == 1) then
    return
  end
  local res = vim.system({ "chezmoi", "source-path" }, { text = true }):wait()
  return res.code == 0 and res.stdout:gsub("[\r\n]+$", "") or nil
end)()

M.CONFIG = M.CHEZMOI and M.CHEZMOI .. "/dot_config/nvim" or vim.fn.stdpath("config") --[[@as string]]

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
  if not M._SHORTEN_PATTERNS then
    local patterns = {
      { M.CONFIG, " " },
      { M.LAZYVIM, "󰒲 " },
      { require("lazy.core.config").options.root, "󰒲 " },
    }
    if M.CHEZMOI then
      table.insert(patterns, { M.CHEZMOI .. "/dot_config", "󱁿 " }) -- 󰒓
      table.insert(patterns, { M.CHEZMOI, "󰠦 " })
      table.insert(patterns, { vim.fn.stdpath("config"), " " }) -- 
    end
    table.insert(patterns, { vim.env.XDG_CONFIG_HOME or vim.env.HOME .. "/.config", "󱁿 " })
    patterns = vim.tbl_map(function(p)
      return { "^" .. vim.pesc(M.home_to_tilde(p[1])) .. "/", p[2] }
    end, patterns)
    M._SHORTEN_PATTERNS = patterns
  end
  for _, p in ipairs(M._SHORTEN_PATTERNS) do
    path = path:gsub(p[1], p[2])
  end
  return U.java.path_shorten(path)
end

return M
