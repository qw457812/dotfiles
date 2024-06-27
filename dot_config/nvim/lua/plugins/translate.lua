return {
  {
    "JuanZoran/Trans.nvim",
    event = "VeryLazy",
    dependencies = { "kkharji/sqlite.lua" },
    build = function()
      -- https://github.com/JuanZoran/Trans.nvim/issues/52#issuecomment-1869952281
      -- Download https://github.com/skywind3000/ECDICT-ultimate/releases/download/1.0.0/ecdict-ultimate-sqlite.zip,
      -- unzip, replace ~/.local/share/nvim/lazy/Trans.nvim/ultimate.db manually.
      -- see: ~/.local/share/nvim/lazy/Trans.nvim/lua/Trans/core/install.lua
      require("Trans").install()
    end,
    keys = {
      -- mm
      { "m<space>", mode = { "n", "x" }, "<Cmd>Translate<CR>", desc = "󰊿 Translate" },
      -- { "mk", mode = { "n", "x" }, "<Cmd>TransPlay<CR>", desc = " Auto Play" },
      -- mi
      { "m<tab>", "<Cmd>TranslateInput<CR>", desc = "󰊿 Translate From Input" },
    },
    -- baidu, youdao settings: ~/.local/share/nvim/lazy/Trans.nvim/Trans.json
    opts = {
      theme = "tokyonight", -- default | tokyonight | dracula
      frontend = {
        ---@class TransFrontendOpts
        default = {
          title = vim.fn.has("nvim-0.9") == 1 and {
            { "", "TransTitleRound" },
            { "󰊿 Translation", "TransTitle" },
            { "", "TransTitleRound" },
          } or nil, -- need nvim-0.9+
          ---@type {open: string | boolean, close: string | boolean, interval: integer} Hover Window Animation
          animation = {
            -- open = "slid", -- 'fold', 'slid'
            -- close = "slid",
            interval = 3, -- default value: 12
          },
        },
        ---@class TransHoverOpts : TransFrontendOpts
        hover = {
          -- -- Max Width of Hover Window
          -- width = 37,
          -- -- Max Height of Hover Window
          -- height = 27,
          -- -- Max Width of Auto Resize
          -- split_width = 60,
          keymaps = {
            close = "q",
          },
          -- order to display translate result
          order = {
            -- default = {
            --   "str",
            --   "translation",
            --   "definition",
            -- },
            offline = {
              "title",
              "translation", -- 中文翻译
              -- "definition", -- 英文注释
              "exchange", -- 词形变化
              "pos", -- 词性
              "tag",
            },
            -- youdao = {
            --   "title",
            --   "translation",
            --   "definition",
            --   "web",
            -- },
          },
          icon = {
            star = "󰓎",
            notfound = "",
          },
        },
      },
    },
  },
}
