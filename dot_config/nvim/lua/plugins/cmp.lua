local function has_words_before()
  local line, col = (unpack or table.unpack)(vim.api.nvim_win_get_cursor(0))
  return col ~= 0 and vim.api.nvim_buf_get_lines(0, line - 1, line, true)[1]:sub(col, col):match("%s") == nil
end

return {
  {
    "saghen/blink.cmp",
    optional = true,
    dependencies = { "xzbdmw/colorful-menu.nvim", shell_command_editor = true },
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
    ---@param opts blink.cmp.Config
    opts = function(_, opts)
      local menu_default = require("blink.cmp.config.completion.menu").default

      local H = {}

      ---@type table<string, blink.cmp.KeymapCommand>
      H.actions = {
        -- https://github.com/folke/snacks.nvim/blob/78f0ad6ce7283b0e2d6ac2b9b82ac731c7c30b93/lua/snacks/input.lua#L195-L209
        pum_next = function()
          if vim.fn.pumvisible() == 0 then
            return
          end
          vim.api.nvim_feedkeys(vim.keycode("<C-n>"), "n", false)
          return true
        end,
        pum_prev = function()
          if vim.fn.pumvisible() == 0 then
            return
          end
          vim.api.nvim_feedkeys(vim.keycode("<C-p>"), "n", false)
          return true
        end,
        pum_accept = function()
          if vim.fn.pumvisible() == 0 then
            return
          end
          vim.api.nvim_feedkeys(vim.keycode("<C-y>"), "n", false)
          return true
        end,
        mini_snippets_expand = function(cmp)
          if not _G.MiniSnippets then
            return
          end
          local function expand()
            MiniSnippets.expand()
            -- HACK: https://github.com/saghen/blink.cmp/blob/cf57b2a708d6b221ab857a8f44f8ca654c5f731c/lua/blink/cmp/config/snippets.lua#L29-L31
            cmp.resubscribe()
          end
          if cmp.is_visible() then
            cmp.cancel({ callback = expand })
          else
            vim.schedule(expand)
          end
          return true
        end,
        copilot_nes = function(cmp)
          if not (package.loaded["copilot-lsp.nes"] and vim.b.nes_state) then
            return
          end
          local nes = require("copilot-lsp.nes")
          cmp.hide()
          return nes.apply_pending_nes() and nes.walk_cursor_end_edit()
        end,
      }

      ---@type table<string, blink.cmp.KeymapCommand>
      H.cmdline_actions = {
        -- is current (selected) item inserted
        is_inserted = function(cmp)
          local item = cmp.get_selected_item()
          if not item then
            return false
          end
          local line_before = vim.fn.getcmdline():sub(1, vim.fn.getcmdpos() - 1)
          -- alternate to `item.source_id == "buffer"`: vim.list_contains({ "/", "?" }, vim.fn.getcmdtype())
          local item_text = item.source_id == "buffer" and item.insertText or (item.textEdit or {}).newText
          if not item_text then
            return false
          end
          return line_before:match(vim.pesc(item_text) .. "$") ~= nil
        end,
        -- insert current (selected) item
        insert = function(cmp)
          if H.cmdline_actions.is_inserted(cmp) then
            return
          end
          -- work-around for insert current
          if #cmp.get_items() > 1 and cmp.get_selected_item_idx() ~= nil then
            cmp.select_next({ auto_insert = false })
            return cmp.select_prev({ auto_insert = true })
          else
            return cmp.select_next({ auto_insert = true }) -- alternate to `cmp.insert_next()`
          end
        end,
      }

      ---@type blink.cmp.Config
      local o = {
        appearance = {
          nerd_font_variant = "normal",
        },
        -- TODO: better snippets/signature keymaps with tab/ctrl-hjkl
        keymap = {
          ["<Tab>"] = {
            "select_next",
            H.actions.pum_next,
            "snippet_forward",
            H.actions.copilot_nes,
            function(cmp)
              if has_words_before() then
                return cmp.show()
              end
            end,
            "fallback",
          },
          ["<S-Tab>"] = { "select_prev", H.actions.pum_prev, "snippet_backward", "fallback" },
          ["<CR>"] = { "accept", H.actions.pum_accept, "fallback" },
          ["<C-n>"] = { "select_next", "show" },
          ["<C-p>"] = { "select_prev", "show" },
          ["<C-j>"] = { "select_next", H.actions.pum_next, H.actions.mini_snippets_expand, "fallback" },
          ["<C-k>"] = { "select_prev", H.actions.pum_prev, "show_signature", "hide_signature", "fallback" },
          ["<C-l>"] = { "snippet_forward", H.actions.mini_snippets_expand, "fallback" },
          ["<C-h>"] = { "snippet_backward", "show_signature", "hide_signature", "fallback" },
          -- ["<C-u>"] = { "scroll_documentation_up", "fallback" },
          -- ["<C-d>"] = { "scroll_documentation_down", "fallback" },
        },
        cmdline = {
          enabled = true,
          keymap = {
            ["<CR>"] = {
              function(cmp)
                if cmp.is_menu_visible() and not H.cmdline_actions.is_inserted(cmp) then
                  return cmp.accept()
                end
              end,
              "fallback",
            },
            ["<Tab>"] = { "show_and_insert", H.cmdline_actions.insert, "select_next" },
            ["<Right>"] = {
              function(cmp)
                if cmp.is_ghost_text_visible() and not H.cmdline_actions.is_inserted(cmp) then
                  return cmp.accept()
                end
              end,
              function(cmp)
                cmp.hide() -- in favor of `fallback`
              end,
              "fallback",
            },
            ["<Left>"] = {
              function(cmp)
                cmp.hide()
              end,
              "fallback",
            },
            ["<C-j>"] = { "select_next", "fallback" },
            ["<C-k>"] = { "select_prev", "fallback" },
            ["<C-a>"] = {
              function(cmp)
                cmp.hide()
              end,
              "fallback",
            },
            ["<C-e>"] = { "cancel", "fallback" },
          },
        },
        completion = {
          ghost_text = {
            enabled = false,
          },
          menu = {
            draw = {
              columns = vim.list_extend(
                vim.tbl_get(opts, "completion", "menu", "draw", "columns")
                  or vim.deepcopy(menu_default.draw.columns --[[@as blink.cmp.DrawColumnDefinition[] ]]),
                {
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
              enabled = function()
                return vim.b.user_blink_path ~= false
              end,
              ---@type blink.cmp.PathOpts|{}
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

  -- HACK: command-line window
  {
    "saghen/blink.cmp",
    optional = true,
    opts = function(_, opts)
      ---@type blink.cmp.Config
      local o = {
        sources = {
          per_filetype = {
            vim = { "cmdline" }, -- I don't need to write vimscript anyway
          },
          providers = {
            cmdline = {
              override = {
                enabled = function(self)
                  return self:enabled() or vim.fn.getcmdwintype() == ":"
                end,
              },
              transform_items = function(ctx, items)
                if vim.fn.getcmdwintype() == ":" then
                  for _, item in ipairs(items) do
                    local text_edit = item.textEdit
                    if text_edit then
                      -- see: https://github.com/saghen/blink.cmp/blob/f820d64680bb5679aa3f493a1b20a06128fc14e0/lua/blink/cmp/sources/cmdline/init.lua#L155-L168
                      text_edit.insert.start.line = ctx.cursor[1] - 1
                      text_edit.insert["end"].line = ctx.cursor[1] - 1
                      text_edit.replace.start.line = ctx.cursor[1] - 1
                      text_edit.replace["end"].line = ctx.cursor[1] - 1
                      text_edit.insert["end"].character = text_edit.replace["end"].character

                      -- see: https://github.com/saghen/blink.cmp/blob/f820d64680bb5679aa3f493a1b20a06128fc14e0/lua/blink/cmp/sources/cmdline/init.lua#L126-L136
                      local is_lua_expr = ctx.line:sub(1, 1) == "="
                      if is_lua_expr then
                        -- copied from: https://github.com/saghen/blink.cmp/blob/f820d64680bb5679aa3f493a1b20a06128fc14e0/lua/blink/cmp/sources/cmdline/init.lua#L24-L32
                        local arguments = vim.split(ctx.line, " ", { plain = true })
                        local arg_number = #vim.split(ctx.line:sub(1, ctx.cursor[2]), " ", { plain = true })
                        local text_before_argument = table.concat(
                          require("blink.cmp.lib.utils").slice(arguments, 1, arg_number - 1),
                          " "
                        ) .. (arg_number > 1 and " " or "")

                        local current_arg = arguments[arg_number]
                        local keyword_config = require("blink.cmp.config").completion.keyword
                        local keyword = ctx.get_bounds(keyword_config.range)
                        local current_arg_prefix = current_arg:sub(1, keyword.start_col - #text_before_argument - 1)

                        text_edit.newText = current_arg_prefix:sub(2, -1) .. text_edit.newText
                      end
                    end
                  end
                end
                return items
              end,
            },
          },
        },
      }
      return U.extend_tbl(opts, o)
    end,
  },

  -- snippet
  {
    "LazyVim/LazyVim",
    opts = function()
      LazyVim.cmp.actions.snippet_active = LazyVim.cmp.actions.snippet_active
        or function()
          return vim.snippet.active()
        end
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
    opts = function(_, opts)
      LazyVim.cmp.actions.snippet_active = function()
        return MiniSnippets.session.get(false) ~= nil
      end
      ---@diagnostic disable-next-line: duplicate-set-field
      LazyVim.cmp.actions.snippet_stop = function()
        MiniSnippets.session.stop()
      end

      local augroup = vim.api.nvim_create_augroup("mini_snippets_auto_stop", { clear = true })
      vim.api.nvim_create_autocmd("BufWritePost", {
        group = augroup,
        callback = function()
          while MiniSnippets.session.get() do
            MiniSnippets.session.stop()
          end
        end,
      })
      vim.api.nvim_create_autocmd("User", {
        group = augroup,
        pattern = "MiniSnippetsSessionJump",
        callback = function(args)
          if args.data.tabstop_to ~= "0" then
            return
          end
          if #MiniSnippets.session.get(true) > 1 then
            MiniSnippets.session.stop()
          else
            vim.api.nvim_create_autocmd("ModeChanged", {
              group = augroup,
              pattern = "*:n",
              once = true,
              callback = MiniSnippets.session.stop,
            })
          end
        end,
      })

      return U.extend_tbl(opts, {
        mappings = {
          expand = "",
          jump_next = "",
          jump_prev = "",
        },
      })
    end,
    specs = {
      {
        "folke/lazydev.nvim",
        opts = function(_, opts)
          opts.library = opts.library or {}
          table.insert(opts.library, { path = "mini.snippets", words = { "MiniSnippets" } })
        end,
      },
    },
  },

  -- signature help
  {
    "saghen/blink.cmp",
    optional = true,
    ---@type blink.cmp.Config
    opts = {
      signature = {
        enabled = true,
        window = {
          show_documentation = true,
        },
      },
    },
    specs = {
      {
        "folke/noice.nvim",
        optional = true,
        ---@module "noice"
        ---@type NoiceConfig|{}
        opts = { lsp = { signature = { enabled = false } } },
      },
    },
  },

  {
    "saghen/blink.cmp",
    optional = true,
    dependencies = { "mikavilpas/blink-ripgrep.nvim", shell_command_editor = true },
    ---@type blink.cmp.Config
    opts = {
      sources = {
        default = { "ripgrep" },
        providers = {
          ripgrep = {
            module = "blink-ripgrep",
            name = "RG",
            min_keyword_length = 3, -- same as `prefix_min_len`
            max_items = 2,
            score_offset = -10,
            ---@module "blink-ripgrep"
            ---@type blink-ripgrep.Options
            opts = {
              prefix_min_len = 3, -- same as `min_keyword_length`
              ignore_paths = { vim.uv.os_homedir() }, -- CPU usage
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
      "garyhurtz/blink_cmp_kitty",
      enabled = vim.g.user_is_kitty,
      shell_command_editor = true,
    },
    opts = vim.g.user_is_kitty and {
      sources = {
        default = { "blink_cmp_kitty" },
        providers = {
          blink_cmp_kitty = {
            module = "blink_cmp_kitty",
            name = "kitty",
            min_keyword_length = 3,
            max_items = 2,
            score_offset = -10,
          },
        },
      },
    } or nil,
  },

  {
    "gbprod/yanky.nvim",
    optional = true,
    specs = {
      {
        "saghen/blink.cmp",
        optional = true,
        dependencies = { "marcoSven/blink-cmp-yanky", shell_command_editor = true },
        ---@type blink.cmp.Config
        opts = {
          sources = {
            default = { "yank" },
            providers = {
              yank = {
                module = "blink-yanky",
                min_keyword_length = 3,
                max_items = 1,
                score_offset = -10,
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
    dependencies = { "ribru17/blink-cmp-spell", shell_command_editor = true },
    ---@type blink.cmp.Config
    opts = {
      sources = {
        default = { "spell" },
        providers = {
          spell = {
            module = "blink-cmp-spell",
            min_keyword_length = 2,
            max_items = 1,
            score_offset = -10,
            opts = {
              preselect_current_word = false,
              use_cmp_spell_sorting = true,
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
      shell_command_editor = true,
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
            max_items = 1,
            score_offset = -20,
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

  -- TODO: https://github.com/philosofonusus/ecolog.nvim
  {
    "saghen/blink.cmp",
    optional = true,
    dependencies = { "bydlw98/blink-cmp-env", shell_command_editor = true },
    ---@type blink.cmp.Config
    opts = {
      sources = {
        default = { "env" },
        providers = {
          env = {
            module = "blink-cmp-env",
            min_keyword_length = 3,
            max_items = 3,
            score_offset = -25,
          },
        },
      },
    },
  },

  -- nvim-cmp {{{

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

  -- }}}
}
