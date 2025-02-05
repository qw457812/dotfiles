-- Declare a global function to retrieve the current directory
-- https://github.com/stevearc/oil.nvim/blob/master/doc/recipes.md#show-cwd-in-the-winbar
function _G.get_oil_winbar()
  local bufnr = vim.api.nvim_win_get_buf(vim.g.statusline_winid)
  local dir = require("oil").get_current_dir(bufnr)
  if dir then
    return vim.fn.fnamemodify(dir, ":~")
  else
    -- If there is no current directory (e.g. over ssh), just show the buffer name
    return vim.api.nvim_buf_get_name(0)
  end
end

local preview_enabled ---@type boolean?

local function toggle_preview()
  preview_enabled = not require("oil.util").get_preview_win()
  require("oil.actions").preview.callback()
end

---@param dir? string
local function open(dir)
  -- respect <C-p> toggle
  require("oil").open(dir, { preview = preview_enabled ~= false and {} or nil })
end

return {
  -- https://github.com/stevearc/dotfiles/blob/eeb506f9afd32cd8cd9f2366110c76efaae5786c/.config/nvim/lua/plugins/oil.lua
  -- https://github.com/Matt-FTW/dotfiles/blob/main/.config/nvim/lua/plugins/extras/editor/oil.lua
  -- https://github.com/kevinm6/nvim/blob/0c2d0fcb04be1f0837ae8918b46131f649cba775/lua/plugins/editor/oil.lua
  -- https://github.com/jellydn/lazy-nvim-ide/blob/main/lua/plugins/extras/oil.lua
  {
    "stevearc/oil.nvim",
    dependencies = { "echasnovski/mini.icons", optional = true },
    cmd = "Oil",
    ---@module 'oil'
    ---@type oil.SetupOpts
    opts = {
      -- whether to use for editing directories (e.g. `vim .` or `:e src/`)
      default_file_explorer = vim.g.user_hijack_netrw == "oil.nvim", -- default value: true
      delete_to_trash = true,
      skip_confirm_for_simple_edits = true,
      -- prompt_save_on_select_new_entry = false,
      watch_for_changes = true,
      win_options = {
        winbar = not U.has_user_extra("ui.dropbar") and "%!v:lua.get_oil_winbar()" or nil,
      },
      keymaps = {
        ["`"] = false,
        ["~"] = false,
        ["<C-h>"] = false,
        ["<C-l>"] = false,
        ["<C-s>"] = false,
        -- ["~"] = {
        --   desc = "<cmd>edit $HOME<CR>",
        --   callback = function()
        --     require("oil").open(vim.env.HOME)
        --   end,
        -- },
        ["gc"] = { "actions.cd", mode = "n" },
        ["gC"] = { "actions.cd", opts = { scope = "tab" }, mode = "n" },
        ["gr"] = "actions.refresh",
        ["<leader>wv"] = { "actions.select", opts = { vertical = true } },
        ["<leader>ws"] = { "actions.select", opts = { horizontal = true } },
        ["<C-p>"] = {
          desc = "Open the entry under the cursor in a preview window, or close the preview window if already open",
          callback = toggle_preview,
        },
        ["<c-space>"] = {
          desc = "Terminal (Oil Dir)",
          callback = function()
            Snacks.terminal(nil, { cwd = require("oil").get_current_dir() })
          end,
        },
        ["gd"] = {
          desc = "Toggle detail view",
          callback = function()
            local oil = require("oil")
            local config = require("oil.config")
            if #config.columns == 1 then
              oil.set_columns({ "icon", "permissions", "size", "mtime" })
            else
              oil.set_columns({ "icon" })
            end
          end,
        },
        ["<leader><space>"] = {
          desc = "Find Files (Oil Dir)",
          function()
            local dir = require("oil").get_current_dir()
            if vim.api.nvim_win_get_config(0).relative ~= "" then
              vim.api.nvim_win_close(0, true)
            end
            Snacks.picker.files({ cwd = dir, hidden = true, ignored = true, follow = true })
          end,
        },
        ["<leader>/"] = {
          desc = "Grep (Oil Dir)",
          function()
            local dir = require("oil").get_current_dir()
            if vim.api.nvim_win_get_config(0).relative ~= "" then
              vim.api.nvim_win_close(0, true)
            end
            LazyVim.pick("live_grep", { cwd = dir })()
          end,
        },
        ["<leader>sr"] = {
          desc = "Search and Replace in Directory (Oil)",
          callback = function()
            local dir = require("oil").get_current_dir()
            if dir then
              U.explorer.grug_far(dir)
            end
          end,
        },
      },
      view_options = {
        show_hidden = true,
        is_always_hidden = function(name, bufnr)
          return name == ".."
        end,
      },
    },
    keys = function()
      local keys = {
        --[[add custom keys here]]
      }

      local opts = LazyVim.opts("oil.nvim")
      -- stylua: ignore
      if opts.default_file_explorer == false then
        vim.list_extend(keys, {
          { "_", function() require("oil").toggle_float() end, desc = "Toggle Float Oil" },
        })
      else
        vim.list_extend(keys, {
          { "-", function() open() end, desc = "Open parent directory (Oil)" },
          { "_", function() open(vim.fn.getcwd()) end, desc = "Open cwd (Oil)" },
        })
      end
      return keys
    end,
    init = function(plugin)
      local opts = LazyVim.opts("oil.nvim")
      if opts.default_file_explorer == false then
        return
      end

      -- https://github.com/stevearc/oil.nvim/issues/300#issuecomment-1950541064
      -- https://github.com/stevearc/oil.nvim/issues/268#issuecomment-1880161152
      local has_ssh_arg = false
      for _, arg in ipairs(vim.fn.argv()) do
        if vim.startswith(arg, "oil-ssh://") then
          has_ssh_arg = true
          break
        end
      end
      if has_ssh_arg then
        require("lazy").load({ plugins = { plugin.name } })
      else
        U.explorer.load_on_directory(plugin.name)
      end
    end,
    config = function(_, opts)
      require("oil").setup(opts)

      -- https://github.com/alexpasmantier/pymple.nvim/blob/eff337420a294e68180c5ee87f03994c0b176dd4/lua/pymple/hooks.lua#L35
      -- https://github.com/stevearc/oil.nvim/issues/310#issuecomment-2019214285
      -- https://github.com/AstroNvim/astrocommunity/blob/6166e840d19b0f6665c8e02c76cba500fa4179b0/lua/astrocommunity/file-explorer/oil-nvim/init.lua#L23
      vim.api.nvim_create_autocmd("User", {
        pattern = "OilActionsPost",
        callback = function(args)
          if args.data.err then
            return
          end
          local parse_url = function(url)
            local _, path = require("oil.util").parse_url(url)
            return assert(path)
          end
          for _, action in ipairs(args.data.actions) do
            ---@cast action oil.Action
            if action.type == "delete" then
              ---@cast action oil.DeleteAction
              local bufnr = vim.fn.bufnr(parse_url(action.url))
              if bufnr ~= -1 then
                -- vim.cmd(("silent! bwipeout! %d"):format(bufnr))
                Snacks.bufdelete({ buf = bufnr, wipe = true })
              end
              -- -- already done, see: https://github.com/stevearc/oil.nvim/issues/184
              -- elseif action.type == "move" then
              --   ---@cast action oil.MoveAction
              --   Snacks.rename.on_rename_file(parse_url(action.src_url), parse_url(action.dest_url))
            end
          end
        end,
      })
    end,
  },

  {
    "nvim-lualine/lualine.nvim",
    optional = true,
    opts = function(_, opts)
      table.insert(opts.extensions, "oil")
    end,
  },
}
