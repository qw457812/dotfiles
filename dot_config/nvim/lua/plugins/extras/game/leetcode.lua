return {
  -- https://github.com/AstroNvim/astrocommunity/blob/90ff9f23f98c4265b37091c6077744b48c19e324/lua/astrocommunity/game/leetcode-nvim/init.lua
  -- https://github.com/AstroNvim/AstroNvim/blob/8fe477244430f91292d0f1a9c3e44ad787091707/lua/astronvim/utils/init.lua#L54
  -- https://github.com/kawre/nvim/blob/e39d243759b5a18cf8eb86c9d761e8fb3e13dcad/lua/plugins/extras/leetcode.lua
  -- https://github.com/search?q=repo%3Akawre%2Fnvim%20leetcode&type=code
  -- https://github.com/ofseed/nvim/blob/338f7742db9739eb6fadfebaafcc5e6c7d316e8d/lua/plugins/tool/leetcode.lua#L29
  -- https://github.com/m1dsolo/dotfiles/blob/c99eef4184a1afe0ab1c01b060d027e34ad0ea7f/.config/nvim/lua/plugins/leetcode-nvim.lua#L84
  {
    "kawre/leetcode.nvim",
    build = ":TSUpdate html",
    cmd = "Leet",
    dependencies = {
      { "MunifTanjim/nui.nvim" },
      { "3rd/image.nvim", optional = true },
      { "nvim-tree/nvim-web-devicons", optional = true },
      {
        "nvim-treesitter/nvim-treesitter",
        optional = true,
        opts = function(_, opts)
          table.insert(opts.ensure_installed, "html")
        end,
      },
    },
    -- or localleader
    keys = {
      { "<leader>LL", "<cmd>Leet<cr>", desc = "Menu" }, -- same as `:Leet menu`, also works for non_standalone
      { "<leader>Lq", "<cmd>Leet exit<cr>", desc = "exit" }, -- for non_standalone
      { "<leader>Ll", "<cmd>Leet lang<cr>", desc = "Lang" },
      { "<leader>Lc", "<cmd>Leet console<cr>", desc = "Console" },
      { "<leader>Lh", "<cmd>Leet info<cr>", desc = "Info" },
      { "<leader>Ld", "<cmd>Leet desc<cr>", desc = "Desc" },
      { "<leader>Lr", "<cmd>Leet restore<cr>", desc = "Restore Layout" },
      { "<leader>LR", "<cmd>Leet reset<cr>", desc = "Reset Code" },
      { "<leader>Ls", "<cmd>Leet submit<cr>", desc = "Submit" },
      { "<leader>LS", "<cmd>Leet last_submit<cr>", desc = "Last Submit" },
      { "<leader>Ly", "<cmd>Leet yank<cr>", desc = "Yank" },
      { "<leader>Lo", "<cmd>Leet open<cr>", desc = "Open in Browser" },
      { "<leader>Lp", "<cmd>Leet list<cr>", desc = "Problem List" },
      { "<leader>LE", "<cmd>Leet list difficulty=Easy<cr>", desc = "Easy Problem List" },
      { "<leader>LM", "<cmd>Leet list difficulty=Medium<cr>", desc = "Medium Problem List" },
      { "<leader>LH", "<cmd>Leet list difficulty=Hard<cr>", desc = "Hard Problem List" },
      { "<leader>Lt", "<cmd>Leet test<cr>", desc = "Test" }, -- same as `:Leet run`
      { "<leader>LT", "<cmd>Leet tabs<cr>", desc = "Tabs" },
      { "<leader>Lu", "<cmd>Leet cache update<cr>", desc = "Update Cache" },
    },
    opts = function(_, opts)
      local augroup = vim.api.nvim_create_augroup("leetcode_diagnostic", { clear = true })
      return U.extend_tbl(opts, {
        lang = "python3", -- java, python3
        image_support = LazyVim.has("image.nvim"),
        cn = { -- leetcode.cn
          enabled = true,
        },
        plugins = {
          non_standalone = true,
        },
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
            -- vim.g.user_is_leetcode = true
            pcall(vim.cmd, [[silent! Copilot disable]])
            vim.api.nvim_create_autocmd("LspAttach", {
              group = augroup,
              desc = "Disable diagnostic virtual text for leetcode by default",
              callback = function()
                if U.toggle.is_diagnostic_virt_enabled == nil then
                  U.toggle.diagnostic_virt:set(false)
                end
              end,
            })
          end,
          ["leave"] = function()
            -- vim.g.user_is_leetcode = false
            vim.api.nvim_clear_autocmds({ group = augroup })
          end,
        },
        keys = {
          toggle = {
            "q",
            -- "<Esc>",
          },
          confirm = { "<CR>" },

          reset_testcases = "R",
          use_testcase = "U",
          focus_testcases = "<C-h>",
          focus_result = "<C-l>",
        },
      })
    end,
    init = function()
      vim.api.nvim_create_autocmd("VimEnter", {
        group = vim.api.nvim_create_augroup("leetcode_autostart", { clear = true }),
        desc = "Start leetcode.nvim on startup",
        nested = true,
        callback = function()
          if vim.fn.argc(-1) ~= 1 then
            return
          end -- return if more than one argument given
          local arg = vim.tbl_get(LazyVim.opts("leetcode.nvim"), "arg") or "leetcode.nvim"
          if vim.fn.argv(0, -1) ~= arg then
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
  {
    "folke/which-key.nvim",
    opts = {
      spec = {
        { "<leader>L", group = "leetcode" },
      },
    },
  },

  {
    "nvimdev/dashboard-nvim",
    optional = true,
    opts = function(_, opts)
      local leetcode = {
        action = "Leet",
        desc = " LeetCode",
        icon = " ", -- " ", " "
        key = "e",
      }

      leetcode.desc = leetcode.desc .. string.rep(" ", 43 - #leetcode.desc)
      leetcode.key_format = "  %s"

      table.insert(opts.config.center, 10, leetcode)
    end,
  },

  {
    "folke/snacks.nvim",
    optional = true,
    opts = function(_, opts)
      table.insert(opts.dashboard.preset.keys, 10, {
        -- action = ":set nobuflisted | Leet",
        action = ":Leet",
        desc = "LeetCode",
        icon = " ",
        key = "e",
      })
    end,
  },
}
