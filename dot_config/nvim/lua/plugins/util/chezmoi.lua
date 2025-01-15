-- do not overwrite <leader>fc if lazyvim.plugins.extras.util.chezmoi not enabled
if not (LazyVim.has_extra("util.chezmoi") and vim.fn.executable("chezmoi") == 1 and U.path.CHEZMOI) then
  return {}
end

---@param opts? { targets?: string|string[], path_style_absolute?: boolean, include_symlinks?: boolean }
---@return string[]
local function chezmoi_list_files(opts)
  opts = opts or {}

  -- exclude directories and externals
  -- see: ~/.local/share/nvim/lazy/chezmoi.nvim/lua/telescope/_extensions/find_files.lua
  local args = { "--include", "files" .. (opts.include_symlinks and ",symlinks" or ""), "--exclude", "externals" }
  if opts.path_style_absolute then
    vim.list_extend(args, { "--path-style", "absolute" })
  end

  return require("chezmoi.commands").list({
    targets = opts.targets or {},
    args = args,
  })
end

local function pick_chezmoi()
  if LazyVim.pick.picker.name == "telescope" then
    require("telescope").extensions.chezmoi.find_files()
  elseif LazyVim.pick.picker.name == "fzf" then
    -- local results = chezmoi_list_files({ include_symlinks = true })
    -- local opts = {
    --   prompt = " ",
    --   fzf_opts = {},
    --   fzf_colors = true,
    --   actions = {
    --     ["default"] = function(selected)
    --       if not vim.tbl_isempty(selected) then
    --         require("chezmoi.commands").edit({ targets = "~/" .. selected[1] })
    --       end
    --     end,
    --   },
    -- }
    -- require("fzf-lua").fzf_exec(results, opts)

    require("fzf-lua").files({
      cmd = "chezmoi managed --path-style=absolute --include=files,symlinks --exclude=externals",
      actions = {
        ["default"] = function(selected, opts)
          require("fzf-lua.actions").vimcmd_entry("ChezmoiEdit", selected, opts)
        end,
      },
    })
  elseif LazyVim.pick.picker.name == "snacks" then
    local managed_files = chezmoi_list_files({ include_symlinks = true, path_style_absolute = true })
    Snacks.picker.pick({
      items = vim.tbl_map(function(file)
        return { file = file, text = U.path.home_to_tilde(file) }
      end, managed_files),
      confirm = function(picker, item)
        picker:close()
        if item then
          require("chezmoi.commands").edit({ targets = assert(Snacks.picker.util.path(item)) })
        end
      end,
    })
  end
end

local function chezmoi_list_config_files()
  return chezmoi_list_files({ targets = vim.fn.stdpath("config"), path_style_absolute = true })
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
  elseif LazyVim.pick.picker.name == "snacks" then
    ---@diagnostic disable-next-line: missing-fields
    Snacks.picker.files({
      cwd = config_dir,
      confirm = function(picker, item)
        picker:close()
        if item then
          if vim.tbl_contains(managed_config_files, item.cwd .. "/" .. item.file) then
            require("chezmoi.commands").edit({ targets = assert(Snacks.picker.util.path(item)) })
          else
            Snacks.picker.actions.edit(picker)
          end
        end
      end,
    })
  end
end

return {
  {
    "xvzc/chezmoi.nvim",
    optional = true,
    event = "LazyFile", -- for augroup: chezmoi_add
    cmd = "ChezmoiEdit",
    keys = {
      { "<leader>sz", false },
      { "<leader>f.", pick_chezmoi, desc = "Find Chezmoi Source Dotfiles" },
      { "<leader>fc", pick_config, desc = "Find Config File" },
    },
    init = function()
      -- https://github.com/xvzc/chezmoi.nvim/pull/20
      vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
        group = vim.api.nvim_create_augroup("chezmoi_apply", { clear = true }),
        pattern = U.path.CHEZMOI .. "/*",
        desc = "chezmoi apply for source-path",
        callback = function(event)
          local buf = event.buf
          vim.schedule(function()
            require("chezmoi.commands.__edit").watch(buf)
          end)
        end,
      })
    end,
    opts = function()
      -- https://github.com/dsully/nvim/blob/a6a7a29707e5209c6bf14be0f178d3cd1141b5ff/lua/plugins/util.lua#L104
      -- https://github.com/amuuname/dotfiles/blob/462579dbf4e9452a22cc268a3cb244172d9142aa/dot_config/nvim/plugin/autocmd.lua#L52
      vim.schedule(function()
        local ok, managed_files = pcall(chezmoi_list_files, { path_style_absolute = true })
        if ok and not vim.tbl_isempty(managed_files) then
          vim.api.nvim_create_autocmd("BufWritePost", {
            group = vim.api.nvim_create_augroup("chezmoi_add", { clear = true }),
            pattern = managed_files,
            desc = "chezmoi add for target-path",
            callback = function(event)
              local res = vim.system({ "chezmoi", "add", event.file }, { text = true }):wait()
              if res.code == 0 then
                LazyVim.info("Successfully added", { title = "Chezmoi" })
              else
                LazyVim.error(
                  ("Failed to add `%s`:\n%s"):format(U.path.home_to_tilde(event.file), res.stderr),
                  { title = "Chezmoi" }
                )
              end
            end,
          })
        end
      end)
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
  },

  {
    "nvim-telescope/telescope.nvim",
    optional = true,
    opts = function(_, opts)
      if not LazyVim.has("telescope-lazy-plugins.nvim") then
        return
      end

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
      local config_idx
      for i, button in ipairs(opts.config.center) do
        if button.key == "c" then
          config_idx = i
          button.action = pick_config
          break
        end
      end

      -- add chezmoi button
      local chezmoi = { action = pick_chezmoi, desc = " Chezmoi", icon = "󰠦 ", key = ".", key_format = "  %s" }
      chezmoi.desc = chezmoi.desc .. string.rep(" ", 43 - #chezmoi.desc)
      table.insert(opts.config.center, (config_idx or #opts.config.center) + 1, chezmoi)
    end,
  },

  {
    "folke/snacks.nvim",
    optional = true,
    opts = function(_, opts)
      local keys = opts.dashboard.preset.keys

      -- replace lazyvim config action
      local config_idx
      for i, key in ipairs(keys) do
        if key.key == "c" then
          config_idx = i
          key.action = pick_config
          break
        end
      end

      -- add chezmoi
      table.insert(
        keys,
        (config_idx or #keys) + 1,
        { action = pick_chezmoi, desc = "Chezmoi", icon = "󰠦 ", key = "." }
      )
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
              [[%s.+ chezmoi: .*: not in source state$]],
              vim.pesc(LazyVim.get_plugin_path("chezmoi.nvim"))
            ),
          },
          view = "mini",
        },
        {
          filter = {
            event = "notify",
            any = {
              { find = "^Edit: Opened a chezmoi%-managed file$" },
              { find = "^Edit: Successfully applied$" },
            },
          },
          view = "mini",
        },
      })
      return opts
    end,
  },
}
