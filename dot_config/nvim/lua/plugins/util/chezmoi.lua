-- do not overwrite <leader>fc if lazyvim.plugins.extras.util.chezmoi not enabled
if not (LazyVim.has_extra("util.chezmoi") and vim.fn.executable("chezmoi") == 1 and U.path.CHEZMOI) then
  return {}
end

-- exclude directories and externals
-- see: ~/.local/share/nvim/lazy/chezmoi.nvim/lua/telescope/_extensions/find_files.lua
local chezmoi_list_args = { "--include", "files", "--exclude", "externals" }

local function pick_chezmoi()
  if LazyVim.pick.picker.name == "telescope" then
    require("telescope").extensions.chezmoi.find_files()
  elseif LazyVim.pick.picker.name == "fzf" then
    local chezmoi = require("chezmoi.commands")
    local results = chezmoi.list({ args = chezmoi_list_args })
    local opts = {
      prompt = " ",
      fzf_opts = {},
      fzf_colors = true,
      actions = {
        ["default"] = function(selected)
          if not vim.tbl_isempty(selected) then
            chezmoi.edit({ targets = "~/" .. selected[1] })
          end
        end,
      },
      -- TODO: previewer
    }
    require("fzf-lua").fzf_exec(results, opts)
  end
end

local function chezmoi_list_config_files()
  return require("chezmoi.commands").list({
    targets = vim.fn.stdpath("config"),
    args = { "--path-style", "absolute", unpack(chezmoi_list_args) },
  })
end

--- pick nvim config
local function pick_config()
  local managed_config_files = chezmoi_list_config_files()
  if vim.tbl_isempty(managed_config_files) then
    LazyVim.pick.config_files()()
    return
  end

  local chezmoi = require("chezmoi.commands")
  local config_dir = vim.fn.stdpath("config")

  if LazyVim.pick.picker.name == "telescope" then
    local actions = require("telescope.actions")
    local action_state = require("telescope.actions.state")
    local config = require("chezmoi").config

    -- https://github.com/nvim-telescope/telescope.nvim/wiki/Configuration-Recipes#performing-an-arbitrary-command-by-extending-existing-find_files-picker
    -- see: ~/.local/share/nvim/lazy/chezmoi.nvim/lua/telescope/_extensions/chezmoi.lua
    require("telescope.builtin").find_files({
      prompt_title = "Config Files",
      cwd = config_dir,
      attach_mappings = function(prompt_bufnr, map)
        -- copied from: https://github.com/xvzc/chezmoi.nvim/blob/faf61465718424696269b2647077331b3e4605f1/lua/telescope/_extensions/find_files.lua#L34
        local edit_action = function()
          actions.close(prompt_bufnr)
          local selection = action_state.get_selected_entry()
          if selection then
            chezmoi.edit({ targets = config_dir .. "/" .. selection.value })
          end
        end

        for _, v in ipairs(config.telescope.select) do
          map("i", v, "select_default")
        end

        -- it's possible that only part of nvim config files are managed with chezmoi
        -- pick them all and edit with or without chezmoi
        actions.select_default:replace_if(function()
          local selection = action_state.get_selected_entry()
          return selection and vim.tbl_contains(managed_config_files, config_dir .. "/" .. selection.value)
        end, edit_action)
        return true
      end,
    })
  elseif LazyVim.pick.picker.name == "fzf" then
    require("fzf-lua").files({
      cwd = config_dir,
      actions = {
        ["default"] = function(selected, opts)
          if vim.tbl_isempty(selected) then
            return
          end

          -- copied from: https://github.com/ibhagwan/fzf-lua/blob/81e7345697d65f6083c681995d230b2d73492233/lua/fzf-lua/actions.lua#L123
          local path = require("fzf-lua.path")
          local file = path.entry_to_file(selected[1], opts).path
          -- if not path.is_absolute(file) then
          --   file = path.join({ opts.cwd or opts._cwd or vim.uv.cwd(), file })
          -- end
          if vim.tbl_contains(managed_config_files, file) then
            chezmoi.edit({ targets = file })
          else
            require("fzf-lua.actions").file_edit(selected, opts)
          end
        end,
      },
    })
  end
end

return {
  {
    "xvzc/chezmoi.nvim",
    optional = true,
    keys = {
      { "<leader>sz", false },
      { "<leader>f.", pick_chezmoi, desc = "Find Chezmoi Source Dotfiles" },
      { "<leader>fc", pick_config, desc = "Find Config File" },
    },
    init = function()
      -- run chezmoi edit on file enter
      -- https://github.com/xvzc/chezmoi.nvim/pull/20
      vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
        pattern = U.path.CHEZMOI .. "/*",
        callback = function(event)
          local buf = event.buf
          vim.schedule(function()
            require("chezmoi.commands.__edit").watch(buf)
          end)
        end,
      })
    end,
  },

  {
    "ibhagwan/fzf-lua",
    optional = true,
    keys = { { "<leader>fc", false } },
  },
  {
    "nvim-telescope/telescope.nvim",
    optional = true,
    keys = { { "<leader>fc", false } },
    opts = function(_, opts)
      local function chezmoi_edit(prompt_bufnr)
        local lp_actions = require("telescope._extensions.lazy_plugins.actions")
        lp_actions.custom_action(prompt_bufnr, "filepath", function(bufnr, entry)
          if vim.tbl_contains(chezmoi_list_config_files(), entry.filepath) then
            lp_actions.append_to_telescope_history(bufnr)
            lp_actions.close(bufnr)
            require("chezmoi.commands").edit({ targets = entry.filepath })
            vim.api.nvim_win_set_cursor(0, { entry.line, 0 })
            vim.cmd("norm! zt")
          else
            lp_actions.open(prompt_bufnr) -- original action
          end
        end)
      end

      opts.extensions = vim.tbl_deep_extend("force", opts.extensions or {}, {
        -- polirritmico/telescope-lazy-plugins.nvim
        lazy_plugins = {
          mappings = {
            ["i"] = { ["<cr>"] = chezmoi_edit },
            ["n"] = { ["<cr>"] = chezmoi_edit },
          },
        },
      })
    end,
  },

  {
    "nvimdev/dashboard-nvim",
    optional = true,
    opts = function(_, opts)
      -- replace lazyvim config action
      local config_idx = 6
      for i, button in ipairs(opts.config.center) do
        if button.key == "c" then
          config_idx = i
          button.action = pick_config
          break
        end
      end

      -- add chezmoi button
      local chezmoi = {
        action = pick_chezmoi,
        desc = " Chezmoi",
        icon = "󰠦 ",
        key = ".",
      }
      chezmoi.desc = chezmoi.desc .. string.rep(" ", 43 - #chezmoi.desc)
      chezmoi.key_format = "  %s"
      table.insert(opts.config.center, config_idx + 1, chezmoi)
    end,
  },

  {
    "folke/noice.nvim",
    optional = true,
    opts = function(_, opts)
      opts.routes = vim.list_extend(opts.routes or {}, {
        {
          filter = {
            event = "msg_show",
            find = string.format(
              [[%s.+ chezmoi: %s.+: not in source state$]],
              vim.pesc(LazyVim.get_plugin_path("chezmoi.nvim")),
              vim.pesc(U.path.CHEZMOI)
            ),
          },
          view = "mini",
        },
      })
      return opts
    end,
  },
}
