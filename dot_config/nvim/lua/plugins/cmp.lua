local function has_words_before()
  local line, col = (unpack or table.unpack)(vim.api.nvim_win_get_cursor(0))
  return col ~= 0 and vim.api.nvim_buf_get_lines(0, line - 1, line, true)[1]:sub(col, col):match("%s") == nil
end

return {
  -- TODO: research
  -- https://github.com/hrsh7th/nvim-cmp/wiki/Example-mappings
  -- https://github.com/LazyVim/LazyVim/blob/330d2e470b79eb31f884685b331d5d255776de90/lua/lazyvim/plugins/compat/nvim-0_9.lua#L3
  -- https://github.com/LazyVim/LazyVim/blob/330d2e470b79eb31f884685b331d5d255776de90/lua/lazyvim/plugins/coding.lua#L109
  -- https://github.com/garymjr/nvim-snippets#installation
  -- https://github.com/LazyVim/LazyVim/blob/330d2e470b79eb31f884685b331d5d255776de90/lua/lazyvim/plugins/extras/coding/luasnip.lua#L41
  -- https://github.com/L3MON4D3/LuaSnip#keymaps
  -- https://github.com/LazyVim/LazyVim/issues/2533
  -- https://github.com/LazyVim/starter/commit/0c370f4d5c537e6d41dea31b547accc8d5f70a8a
  --
  -- https://www.lazyvim.org/configuration/recipes#supertab
  -- use <tab> for completion and snippets (supertab)
  {
    "nvim-cmp",
    optional = true,
    ---@param opts cmp.ConfigSchema
    opts = function(_, opts)
      local cmp = require("cmp")

      opts.mapping = vim.tbl_extend("force", opts.mapping, {
        ["<Tab>"] = cmp.mapping(function(fallback)
          if cmp.visible() then
            -- You could replace select_next_item() with confirm({ select = true }) to get VS Code autocompletion behavior
            cmp.select_next_item()
          elseif vim.snippet.active({ direction = 1 }) then
            vim.schedule(function()
              vim.snippet.jump(1)
            end)
          elseif has_words_before() then
            cmp.complete()
          else
            fallback()
          end
        end, { "i", "s" }),
        ["<S-Tab>"] = cmp.mapping(function(fallback)
          if cmp.visible() then
            cmp.select_prev_item()
          elseif vim.snippet.active({ direction = -1 }) then
            vim.schedule(function()
              vim.snippet.jump(-1)
            end)
          else
            fallback()
          end
        end, { "i", "s" }),
      })
    end,
  },

  {
    "saghen/blink.cmp",
    optional = true,
    ---@module 'blink.cmp'
    ---@param opts blink.cmp.Config
    opts = function(_, opts)
      local menu_default = require("blink.cmp.config.completion.menu").default

      -- -- blink is broken in cmdwin
      -- vim.api.nvim_create_autocmd("CmdWinEnter", {
      --   callback = function(event)
      --     vim.b[event.buf].completion = false
      --   end,
      -- })

      ---@type blink.cmp.Config
      local o = {
        -- copied from: https://github.com/AstroNvim/astrocommunity/blob/31e12fdbcba1ae7094d8b027c6e65d01e6f133e9/lua/astrocommunity/completion/blink-cmp/init.lua#L66
        keymap = {
          ["<Tab>"] = {
            ---@param cmp blink.cmp.API
            function(cmp)
              if cmp.is_visible() then
                return cmp.select_next()
              elseif cmp.snippet_active({ direction = 1 }) then
                return cmp.snippet_forward()
              elseif has_words_before() then
                return cmp.show()
              end
            end,
            "fallback",
          },
          ["<S-Tab>"] = {
            ---@param cmp blink.cmp.API
            function(cmp)
              if cmp.is_visible() then
                return cmp.select_prev()
              elseif cmp.snippet_active({ direction = -1 }) then
                return cmp.snippet_backward()
              end
            end,
            "fallback",
          },
          -- -- https://github.com/y3owk1n/nix-system-config-v2/blob/ae72dd82a92894a1ca8c5ff4243e0208dfc33a5d/config/nvim/lua/plugins/blink-cmp.lua#L19
          -- ["<Esc>"] = {
          --   ---@param cmp blink.cmp.API
          --   function(cmp)
          --     if cmp.is_visible() then
          --       if cmp.snippet_active() then
          --         return cmp.hide()
          --       end
          --     end
          --   end,
          --   "fallback",
          -- },
          ["<C-j>"] = { "select_next", "fallback" },
          ["<C-k>"] = { "select_prev", "fallback" },
          -- ["<C-u>"] = { "scroll_documentation_up", "fallback" },
          -- ["<C-d>"] = { "scroll_documentation_down", "fallback" },
        },
        completion = {
          menu = {
            draw = {
              columns = vim.list_extend(vim.deepcopy(assert(menu_default.draw.columns)), {
                -- { "kind" },
                { "source_name" },
              }),
              components = {
                kind_icon = {
                  text = function(ctx)
                    if ctx.item.source_name == "LSP" and ctx.kind then
                      local icon, _, is_default = require("mini.icons").get("lsp", ctx.kind)
                      ctx.kind_icon = is_default and ctx.kind_icon or icon
                    end
                    return menu_default.draw.components.kind_icon.text(ctx)
                  end,
                },
                source_name = {
                  text = function(ctx)
                    return "[" .. ctx.source_name .. "]"
                  end,
                },
              },
            },
          },
        },
      }

      return U.extend_tbl(opts, o)
    end,
  },

  {
    "saghen/blink.cmp",
    optional = true,
    dependencies = {
      "mikavilpas/blink-ripgrep.nvim",
    },
    ---@module 'blink.cmp'
    ---@type blink.cmp.Config
    opts = {
      sources = {
        default = { "ripgrep" },
        providers = {
          ripgrep = {
            module = "blink-ripgrep",
            name = "RG",
            min_keyword_length = 3, -- same as `prefix_min_len`
            max_items = 3,
            score_offset = -5,
            enabled = function()
              -- CPU usage
              return LazyVim.root({ normalize = true }) ~= U.path.HOME
            end,
            ---@module "blink-ripgrep"
            ---@type blink-ripgrep.Options
            opts = {
              prefix_min_len = 3, -- same as `min_keyword_length`
              -- search_casing = "--smart-case",

              -- or use custom `get_command` function
              project_root_marker = function(_, path)
                return path == LazyVim.root({ normalize = true })
              end,
            },
          },
        },
      },
    },
  },

  {
    "saghen/blink.cmp",
    optional = true,
    dependencies = {
      "Kaiser-Yang/blink-cmp-dictionary",
    },
    ---@type blink.cmp.Config
    opts = {
      sources = {
        default = { "dictionary" },
        providers = {
          dictionary = {
            module = "blink-cmp-dictionary",
            name = "Dict",
            min_keyword_length = 3,
            max_items = 3,
            score_offset = -10,
            --- @module 'blink-cmp-dictionary'
            --- @type blink-cmp-dictionary.Options
            opts = {
              -- aspell -d en_US dump master | aspell -l en expand | sed 's/\s\+/\n/g' > aspell_en.dict
              dictionary_files = { vim.fn.stdpath("data") .. "/cmp-dictionary/dict/aspell_en.dict" },
              separate_output = vim.fn.executable("wn") == 0 and function(output)
                local items = {}
                for line in output:gmatch("[^\r\n]+") do
                  table.insert(items, {
                    label = line,
                    insert_text = line,
                  })
                end
                return items
              end or nil,
            },
          },
        },
      },
    },
  },

  vim.fn.executable("gh") == 1
      and {
        "saghen/blink.cmp",
        optional = true,
        dependencies = {
          "Kaiser-Yang/blink-cmp-git",
        },
        ---@type blink.cmp.Config
        opts = {
          sources = {
            default = { "git" },
            providers = {
              git = {
                module = "blink-cmp-git",
                name = "Git",
                score_offset = 100,
                enabled = function()
                  return Snacks.git.get_root() ~= nil
                end,
                should_show_items = function()
                  return vim.list_contains({
                    "gitcommit",
                    -- "markdown",
                  }, vim.bo.filetype)
                end,
                ---@module 'blink-cmp-git'
                ---@type blink-cmp-git.Options
                opts = {},
              },
            },
          },
        },
      }
    or nil,
}
