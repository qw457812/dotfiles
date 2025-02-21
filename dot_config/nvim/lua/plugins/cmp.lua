LazyVim.cmp.actions.snippet_active = function()
  return vim.snippet.active()
end

local function has_words_before()
  local line, col = (unpack or table.unpack)(vim.api.nvim_win_get_cursor(0))
  return col ~= 0 and vim.api.nvim_buf_get_lines(0, line - 1, line, true)[1]:sub(col, col):match("%s") == nil
end

return {
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
    dependencies = "xzbdmw/colorful-menu.nvim",
    ---@module 'blink.cmp'
    ---@type blink.cmp.Config
    opts = {
      completion = {
        menu = {
          draw = {
            columns = { { "kind_icon" }, { "label", gap = 1 } },
            components = {
              label = {
                text = function(ctx)
                  return require("colorful-menu").blink_components_text(ctx)
                end,
                highlight = function(ctx)
                  return require("colorful-menu").blink_components_highlight(ctx)
                end,
              },
            },
          },
        },
      },
    },
  },
  {
    "saghen/blink.cmp",
    optional = true,
    ---@module 'blink.cmp'
    ---@param opts blink.cmp.Config
    opts = function(_, opts)
      local menu_default = require("blink.cmp.config.completion.menu").default

      -- HACK: copied from: https://github.com/neovim/neovim/issues/30198#issuecomment-2326075321
      if vim.fn.has("nvim-0.11") == 1 then
        -- Ensure that forced and not configurable `<Tab>` and `<S-Tab>`
        -- buffer-local mappings don't override already present ones
        local expand_orig = vim.snippet.expand
        vim.snippet.expand = function(...)
          local tab_map = vim.fn.maparg("<Tab>", "i", false, true)
          local stab_map = vim.fn.maparg("<S-Tab>", "i", false, true)
          expand_orig(...)
          vim.schedule(function()
            tab_map.buffer, stab_map.buffer = 1, 1
            -- Override temporarily forced buffer-local mappings
            vim.fn.mapset("i", false, tab_map)
            vim.fn.mapset("i", false, stab_map)
          end)
        end
      end

      -- -- blink is broken in cmdwin
      -- vim.api.nvim_create_autocmd("CmdWinEnter", {
      --   callback = function(event)
      --     vim.b[event.buf].completion = false
      --   end,
      -- })

      ---@type blink.cmp.Config
      local o = {
        -- copied from: https://github.com/AstroNvim/astrocommunity/blob/0e1cf1178a6c0b2bfbc1e5e0d4a3009911b07649/lua/astrocommunity/completion/blink-cmp/init.lua#L98
        keymap = {
          -- TODO: better coop with mini.snippets and signature_help
          ["<Tab>"] = {
            "select_next",
            "snippet_forward",
            function(cmp)
              if has_words_before() then
                return cmp.show()
              end
            end,
            "fallback",
          },
          ["<S-Tab>"] = { "select_prev", "snippet_backward", "fallback" },
          -- -- https://github.com/y3owk1n/nix-system-config-v2/blob/ae72dd82a92894a1ca8c5ff4243e0208dfc33a5d/config/nvim/lua/plugins/blink-cmp.lua#L19
          -- ["<Esc>"] = {
          --   function(cmp)
          --     if cmp.is_visible() then
          --       if cmp.snippet_active() then
          --         return cmp.hide()
          --       end
          --     end
          --   end,
          --   "fallback",
          -- },
          ["<C-n>"] = { "select_next", "show" },
          ["<C-p>"] = { "select_prev", "show" },
          -- ["<C-j>"] = { "select_next", "fallback" }, -- conflicts with mini.snippets
          -- ["<C-k>"] = { "select_prev", "fallback" },
          -- ["<C-u>"] = { "scroll_documentation_up", "fallback" },
          -- ["<C-d>"] = { "scroll_documentation_down", "fallback" },
        },
        completion = {
          menu = {
            draw = {
              columns = vim.list_extend(
                vim.tbl_get(opts, "completion", "menu", "draw", "columns") or vim.deepcopy(menu_default.draw.columns),
                {
                  -- { "kind" },
                  { "source_name" },
                }
              ),
              components = {
                -- kind_icon = {
                --   text = function(ctx)
                --     if ctx.item.source_name == "LSP" and ctx.kind then
                --       local icon, _, is_default = require("mini.icons").get("lsp", ctx.kind)
                --       ctx.kind_icon = is_default and ctx.kind_icon or icon
                --     end
                --     return menu_default.draw.components.kind_icon.text(ctx)
                --   end,
                -- },
                source_name = {
                  text = function(ctx)
                    return "[" .. ctx.source_name .. "]"
                  end,
                  highlight = "NonText",
                },
              },
            },
          },
        },
        sources = {
          providers = {
            path = {
              ---@type blink.cmp.PathOpts
              opts = {
                show_hidden_files_by_default = true,
              },
            },
          },
        },
      }

      return U.extend_tbl(opts, o)
    end,
  },

  {
    "L3MON4D3/LuaSnip",
    optional = true,
    opts = function()
      -- see: https://github.com/Saghen/blink.cmp/blob/f0f34c318af019b44fc8ea347895dcf92b682122/lua/blink/cmp/config/snippets.lua#L34
      LazyVim.cmp.actions.snippet_active = function()
        return require("luasnip").in_snippet()
      end
    end,
  },
  {
    "echasnovski/mini.snippets",
    optional = true,
    opts = function()
      LazyVim.cmp.actions.snippet_active = function()
        return MiniSnippets.session.get(false) ~= nil
      end
      ---@diagnostic disable-next-line: duplicate-set-field
      LazyVim.cmp.actions.snippet_stop = function()
        MiniSnippets.session.stop()
      end
    end,
  },

  {
    "saghen/blink.cmp",
    optional = true,
    dependencies = "mikavilpas/blink-ripgrep.nvim",
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
            ---@module "blink-ripgrep"
            ---@type blink-ripgrep.Options
            opts = {
              prefix_min_len = 3, -- same as `min_keyword_length`
              ignore_paths = { vim.uv.os_homedir() }, -- CPU usage
              -- search_casing = "--smart-case",

              -- or use custom `get_command` function
              project_root_marker = function(_, path)
                return path == LazyVim.root({ normalize = true })
              end,
              project_root_fallback = false,
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
      -- TODO: add dict downloading to build
      init = function()
        LazyVim.on_load("mini.icons", function()
          require("snacks.util").set_hl({ BlinkCmpKindDict = "MiniIconsRed" })
        end)
      end,
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
            ---@module 'blink-cmp-dictionary'
            ---@type blink-cmp-dictionary.Options
            opts = {
              dictionary_files = {
                -- aspell -d en_US dump master | aspell -l en expand | sed 's/\s\+/\n/g' > aspell_en.dict
                vim.fn.stdpath("data") .. "/cmp-dictionary/dict/aspell_en.dict",
                -- -- https://github.com/dwyl/english-words/blob/8179fe68775df3f553ef19520db065228e65d1d3/words_alpha.txt
                -- vim.fn.stdpath("data") .. "/cmp-dictionary/dict/words_alpha.txt",
              },
            },
          },
        },
      },
    },
  },

  {
    "saghen/blink.cmp",
    optional = true,
    dependencies = "ribru17/blink-cmp-spell",
    ---@type blink.cmp.Config
    opts = {
      sources = {
        default = { "spell" },
        providers = {
          spell = {
            module = "blink-cmp-spell",
            name = "Spell",
            max_items = 3,
            score_offset = -10,
            opts = {
              -- only enable source in `@spell` captures, and disable it in `@nospell` captures
              enable_in_context = function()
                local is_spell = false
                for _, capture in ipairs(vim.treesitter.get_captures_at_cursor(0)) do
                  if capture == "spell" then
                    is_spell = true
                  elseif capture == "nospell" then
                    return false
                  end
                end
                return is_spell
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
    ---@param opts blink.cmp.Config
    opts = function(_, opts)
      local fuzzy_default = require("blink.cmp.config.fuzzy").default

      opts.fuzzy = opts.fuzzy or {}
      opts.fuzzy.sorts = {
        function(a, b)
          local sort = require("blink.cmp.fuzzy.sort")
          if a.source_id == "spell" and b.source_id == "spell" then
            return sort.label(a, b)
          end
        end,
        unpack(opts.fuzzy.sorts or fuzzy_default.sorts),
      }
    end,
  },

  {
    "saghen/blink.cmp",
    optional = true,
    dependencies = "bydlw98/blink-cmp-env",
    ---@type blink.cmp.Config
    opts = {
      sources = {
        default = { "env" },
        providers = {
          env = {
            module = "blink-cmp-env",
            name = "Env",
            min_keyword_length = 3,
            max_items = 3,
            score_offset = -10,
          },
        },
      },
    },
  },

  -- vim.fn.executable("gh") == 1
  --     and {
  --       "saghen/blink.cmp",
  --       optional = true,
  --       dependencies = "Kaiser-Yang/blink-cmp-git",
  --       ---@type blink.cmp.Config
  --       opts = {
  --         sources = {
  --           default = { "git" },
  --           providers = {
  --             git = {
  --               module = "blink-cmp-git",
  --               name = "Git",
  --               score_offset = 100,
  --               enabled = function()
  --                 return Snacks.git.get_root() ~= nil
  --               end,
  --               should_show_items = function()
  --                 return vim.list_contains({
  --                   "gitcommit",
  --                   -- "markdown",
  --                 }, vim.bo.filetype)
  --               end,
  --               ---@module 'blink-cmp-git'
  --               ---@type blink-cmp-git.Options
  --               opts = {},
  --             },
  --           },
  --         },
  --       },
  --     }
  --   or nil,
}
