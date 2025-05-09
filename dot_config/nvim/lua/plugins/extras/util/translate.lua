return {
  {
    "JuanZoran/Trans.nvim",
    pager = true,
    dependencies = { "kkharji/sqlite.lua", pager = true },
    build = function()
      -- https://github.com/JuanZoran/Trans.nvim/issues/52#issuecomment-1869952281
      -- Download https://github.com/skywind3000/ECDICT-ultimate/releases/download/1.0.0/ecdict-ultimate-sqlite.zip,
      -- unzip, replace ~/.local/share/nvim/lazy/Trans.nvim/ultimate.db manually.
      -- see: ~/.local/share/nvim/lazy/Trans.nvim/lua/Trans/core/install.lua
      require("Trans").install()
    end,
    keys = {
      {
        "m<space>",
        mode = {
          "n",
          -- "x",
        },
        function()
          require("Trans").translate() -- `Translate` cmd conflicts with smart-translate.nvim
        end,
        desc = "Translate",
      },
      -- { "m<tab>", "<Cmd>TranslateInput<CR>", desc = "Translate From Input" },
    },
    -- baidu, youdao settings: ~/.local/share/nvim/lazy/Trans.nvim/Trans.json
    opts = {
      theme = "tokyonight", -- default | tokyonight | dracula
      frontend = {
        ---@class TransFrontendOpts
        default = {
          title = "", -- disable title
          ---@type {open: string | boolean, close: string | boolean, interval: integer} Hover Window Animation
          animation = {
            -- open = "slid", -- 'fold', 'slid'
            -- close = "slid",
            interval = 1, -- default value: 12
          },
          timeout = 5000,
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
            pageup = "<C-b>", -- same as Lsp Hover Doc Scrolling
            pagedown = "<C-f>",
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
              -- "tag",
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
            notfound = "", -- 
            yes = "",
            no = "",
            translation = "",
          },
        },
      },
    },
    config = function(_, opts)
      local Trans = require("Trans")
      Trans.setup(opts)

      -- fix: on colorscheme change
      local highlights = Trans.style.theme[opts.theme or "default"]
      Snacks.util.set_hl(highlights)

      local node = Trans.util.node
      ---@diagnostic disable-next-line: undefined-field
      local item = node.item
      -- HACK: icon only
      ---@diagnostic disable-next-line: inject-field
      function node.prompt(str)
        return {
          item({ "", "TransTitleRound" }),
          item({ str:match("^%S+") or "", "MiniIconsAzure" }),
          item({ "", "TransTitleRound" }),
        }
      end

      if LazyVim.has("smart-translate.nvim") then
        local hover = Trans.frontend.hover
        -- HACK: fallback to smart-translate.nvim, need to disable baidu/youdao first
        function hover:fallback()
          -- https://github.com/JuanZoran/Trans.nvim/blob/fcde85544a7bfeda587fb35dd654c30632c48481/lua/Trans/frontend/hover/init.lua#L149-L189
          Trans.util.main_loop(function()
            vim.defer_fn(function()
              self:destroy()
              require("lazy").load({ plugins = { "smart-translate.nvim" } })
              vim.cmd(("Translate --handle=float %s"):format(vim.fn.expand("<cword>")))
            end, 0)
          end)
        end
      end
    end,
  },

  {
    "askfiy/smart-translate.nvim",
    pager = true,
    dependencies = { "askfiy/http.nvim", pager = true },
    cmd = "Translate",
    -- keys = {
    --   { "m<space>", mode = "x", [[:Translate<CR>]], desc = "Translate" },
    -- },
    opts = {},
  },

  {
    "potamides/pantran.nvim",
    pager = true,
    cmd = "Pantran",
    keys = {
      {
        "m<space>",
        mode = {
          -- "n",
          "x",
        },
        function()
          -- return require("pantran").motion_translate({ mode = "hover" })
          return require("pantran").motion_translate()
        end,
        expr = true,
        desc = "Translate Motion",
      },
      -- {
      --   "m<space><space>",
      --   function()
      --     return require("pantran").motion_translate() .. "_"
      --   end,
      --   expr = true,
      --   desc = "Translate Motion",
      -- },
      { "m<tab>", "<cmd>Pantran<CR>i", desc = "Translate Prompt" },
    },
    opts = function(_, opts)
      local actions = require("pantran.ui.actions")

      Snacks.util.set_hl({ PantranBorder = "FloatBorder" })
      return U.extend_tbl(opts, {
        -- command = {
        --   default_mode = "hover",
        -- },
        default_engine = "google",
        engines = {
          google = {
            default_source = "auto",
            default_target = "zh-CN",
            fallback = {
              default_source = "auto",
              default_target = "zh-CN",
            },
          },
        },
        controls = {
          mappings = {
            edit = {
              i = {
                ["<C-c>"] = function(ui)
                  vim.cmd("stopinsert")
                  actions.close(ui)
                end,
              },
            },
          },
        },
        ui = {
          width_percentage = vim.g.user_is_termux and 0.95 or 0.8,
          height_percentage = vim.g.user_is_termux and 0.9 or 0.8,
        },
        window = {
          title_border = { "", "" },
          options = {
            filetype = "pantran",
          },
        },
      })
    end,
    config = function(_, opts)
      require("pantran").setup(opts)

      -- NOTE: do not require modules of pantran in `opts` function except require("pantran.ui.actions")
      -- see: https://github.com/potamides/pantran.nvim/blob/b87c3ae48cba4659587fb75abd847e5b7a7c9ca0/lua/pantran/ui/actions.lua#L1-L4
      local fallback_google = require("pantran.engines.fallback.google")
      -- HACK: increase title width after customize `title_border`
      fallback_google.name = fallback_google.name .. "    "
    end,
  },
}
