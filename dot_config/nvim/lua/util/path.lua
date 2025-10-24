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

-- vim.env.HOME -- https://github.com/LazyVim/LazyVim/commit/231e476
-- vim.fs.normalize("~")
M.HOME = assert(vim.uv.os_homedir())

--- Chezmoi source path
M.CHEZMOI = (function()
  if not (LazyVim.has_extra("util.chezmoi") and vim.fn.executable("chezmoi") == 1) then
    return
  end
  local res = vim.system({ "chezmoi", "source-path" }, { text = true }):wait()
  return res.code == 0 and res.stdout:gsub("\n+$", "") or nil
end)()

M.CONFIG = M.CHEZMOI and M.CHEZMOI .. "/dot_config/nvim" or vim.fn.stdpath("config") --[[@as string]]

M.LAZYVIM = LazyVim.get_plugin_path("LazyVim")

--- Replace home directory with '~'
--- https://github.com/nvim-mini/mini.files/blob/10ed64157ec45f176decefbdb0e2ba10cccd187f/lua/mini/files.lua#L2365
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

-- * special: special paths like dotfiles, defaults to true
-- * relative: relative to cwd/root or provided path if possible, defaults to true, same as vim.fn.getcwd()
-- * java: java paths, defaults to true
---@alias PathShortenOpts {special?: boolean, relative?: boolean|string, java?: boolean}

---@param path string
---@param opts? PathShortenOpts
---@return string
function M.shorten(path, opts)
  opts = vim.tbl_deep_extend("force", {
    special = true,
    relative = true,
    java = true,
  }, opts or {}) --[[@as PathShortenOpts]]

  local path_orig = path
  if opts.special then
    if not M._SHORTEN_PATTERNS then
      local patterns = {
        { M.CONFIG, " " },
        { M.LAZYVIM, "󰒲 " },
        { require("lazy.core.config").options.root, "󰒲 " },
      }
      if M.CHEZMOI then
        table.insert(patterns, { M.CHEZMOI .. "/dot_config", "󱁿 " }) -- 󰒓 
        table.insert(patterns, { M.CHEZMOI, "󰠦 " })
        table.insert(patterns, { vim.fn.stdpath("config"), " " }) -- 
      end
      table.insert(patterns, { vim.env.XDG_CONFIG_HOME or vim.env.HOME .. "/.config", "󱁿 " })
      patterns = vim.tbl_map(function(p)
        return { "^" .. vim.pesc(p[1]) .. "/", p[2] }
      end, patterns)
      M._SHORTEN_PATTERNS = patterns
    end
    for _, p in ipairs(M._SHORTEN_PATTERNS) do
      path = path:gsub(p[1], p[2])
    end
  end

  -- special paths take precedence over relative paths
  if path == path_orig and opts.relative then
    -- copied from: https://github.com/folke/snacks.nvim/blob/e039139291f85eebf3eeb41cc5ad9dc4265cafa4/lua/snacks/picker/util/init.lua#L21-L35
    local cwd = type(opts.relative) == "string"
        and vim.fs.normalize(opts.relative --[[@as string]], { _fast = true, expand_env = false })
      or vim.fn.getcwd()
    if path:find(cwd .. "/", 1, true) == 1 and #path > #cwd then
      path = path:sub(#cwd + 2)
    else
      local root = LazyVim.root({ normalize = true })
      if not (path:find(root .. "/", 1, true) == 1 and #path > #root) then
        root = Snacks.git.get_root(path) or ""
      end
      if root ~= "" and path:find(root, 1, true) == 1 then
        local tail = vim.fn.fnamemodify(root, ":t")
        path = "⋮" .. tail .. "/" .. path:sub(#root + 2)
      elseif path:find(M.HOME, 1, true) == 1 then
        path = "~" .. path:sub(#M.HOME + 1)
      end
    end
  else
    path = M.home_to_tilde(path)
  end

  return opts.java and U.java.path_shorten(path) or path
end

return M
