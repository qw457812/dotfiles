return {
  -- https://github.com/AstroNvim/astrocommunity/blob/90ff9f23f98c4265b37091c6077744b48c19e324/lua/astrocommunity/game/leetcode-nvim/init.lua
  -- https://github.com/search?q=repo%3Akawre%2Fnvim%20leetcode&type=code
  -- TODO disable copilot (and autoformat?) for leetcode
  -- https://github.com/kawre/nvim/blob/e39d243759b5a18cf8eb86c9d761e8fb3e13dcad/lua/plugins/extras/leetcode.lua#L52
  -- https://github.com/ofseed/nvim/blob/338f7742db9739eb6fadfebaafcc5e6c7d316e8d/lua/plugins/tool/leetcode.lua#L29
  -- https://github.com/TobinPalmer/dots/blob/2dd6a633deecd5badd5c5f8d91985ab0d68f1a24/nvim/lua/plugins/misc.lua#L88
  -- https://github.com/hnbnh/dotfiles/blob/de3fdbeef9aab5ebe91333403d5c579b4915aa43/config/nvim/lua/plugins/misc.lua#L90
  -- https://github.com/m1dsolo/dotfiles/blob/c99eef4184a1afe0ab1c01b060d027e34ad0ea7f/.config/nvim/lua/plugins/leetcode-nvim.lua#L84
  -- https://github.com/catgoose/nvim/blob/31407a09d932f9307dea720a68ccb84d9faa1f76/lua/plugins/leetcode.lua#L56
  -- TODO keys
  {
    "kawre/leetcode.nvim",
    build = ":TSUpdate html",
    cmd = "Leet",
    dependencies = {
      { "nvim-telescope/telescope.nvim" },
      { "nvim-lua/plenary.nvim" }, -- required by telescope
      { "MunifTanjim/nui.nvim" },

      -- optional
      { "rcarriga/nvim-notify", optional = true },
      { "nvim-tree/nvim-web-devicons", optional = true },
      {
        "nvim-treesitter/nvim-treesitter",
        optional = true,
        opts = function(_, opts)
          if opts.ensure_installed ~= "all" and not vim.list_contains(opts.ensure_installed, "html") then
            table.insert(opts.ensure_installed, "html")
          end
        end,
      },
    },
    opts = {
      lang = "java", -- java, python3
      -- cn = { -- leetcode.cn
      --   enabled = true,
      -- },
      -- plugins = {
      --   non_standalone = true,
      -- },
      injector = {
        ["java"] = {
          before = true, -- access default imports via `require("leetcode.config.imports")`
        },
        ["python3"] = {
          before = true,
        },
      },
      hooks = {
        ["enter"] = function()
          pcall(vim.cmd, [[silent! Copilot disable]])
        end,
      },
      -- keys = {
      --   toggle = { "q" },
      --   confirm = { "<CR>" },
      --
      --   reset_testcases = "r",
      --   use_testcase = "U",
      --   focus_testcases = "H",
      --   focus_result = "L",
      -- },
    },
    init = function()
      vim.api.nvim_create_autocmd("VimEnter", {
        group = vim.api.nvim_create_augroup("leetcode_autostart", { clear = true }),
        desc = "Start leetcode.nvim on startup",
        nested = true,
        callback = function()
          if vim.fn.argc() ~= 1 then
            return
          end -- return if more than one argument given
          local arg = vim.tbl_get(LazyVim.opts("leetcode.nvim"), "arg") or "leetcode.nvim"
          if vim.fn.argv()[1] ~= arg then
            return
          end -- return if argument doesn't match trigger
          local lines = vim.api.nvim_buf_get_lines(0, 0, -1, true)
          if #lines > 1 or (#lines == 1 and lines[1]:len() > 0) then
            return
          end -- return if buffer is non-empty
          require("leetcode").start(true)
        end,
      })
    end,
  },

  -- https://github.com/kawre/nvim/blob/e39d243759b5a18cf8eb86c9d761e8fb3e13dcad/lua/plugins/extras/copilot.lua#L36
  -- {
  --   "zbirenbaum/copilot.lua",
  --   optional = true,
  --   opts = {
  --     filetypes = { ["leetcode.nvim"] = false },
  --   },
  -- },
}
