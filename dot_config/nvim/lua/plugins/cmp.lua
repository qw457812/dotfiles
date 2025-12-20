local function has_words_before()
  local line, col = (unpack or table.unpack)(vim.api.nvim_win_get_cursor(0))
  return col ~= 0 and vim.api.nvim_buf_get_lines(0, line - 1, line, true)[1]:sub(col, col):match("%s") == nil
end

-- https://github.com/Saghen/nvim/blob/06849f05f2057e4fa7774bdba0d9b70d785716f0/lua/core/blink.lua
---@type LazySpec
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
    -- https://github.com/Saghen/blink.cmp/issues/145#issuecomment-2483686337
    -- https://github.com/Saghen/blink.cmp/issues/145#issuecomment-2492759016
    build = vim.g.lazyvim_blink_main and ("%s cargo build --release"):format(
      vim.g.user_is_termux and 'RUSTC_BOOTSTRAP=1 RUSTFLAGS="-C link-args=-lluajit"' or ""
    ),
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
          return true -- no way to know whether expansion happened or not
        end,
        snippet_stop = function()
          if not LazyVim.cmp.actions.snippet_active() then
            return
          end
          vim.schedule(LazyVim.cmp.actions.snippet_stop)
          return true
        end,
        -- see: https://github.com/Saghen/blink.cmp/issues/569#issuecomment-2833362734
        scroll_list_up = function()
          -- based on select_prev: https://github.com/Saghen/blink.cmp/blob/6323a6ddb191323904557dc9b545f309ea2b0e12/lua/blink/cmp/init.lua#L200-L205
          if not require("blink.cmp.completion.list").can_select() then
            return
          end
          vim.schedule(function()
            -- see: https://github.com/saghen/blink.cmp/blob/7856f05dd48ea7f2c68ad3cba40202f8a9369b9e/lua/blink/cmp/lib/window/init.lua#L237-L241
            local page_size = vim.api.nvim_win_get_height(require("blink.cmp.completion.windows.menu").win:get_win())
            -- half page up
            require("blink.cmp.completion.list").select_prev({ count = math.floor(page_size / 2) })
          end)
          return true
        end,
        scroll_list_down = function()
          -- based on select_next: https://github.com/Saghen/blink.cmp/blob/6323a6ddb191323904557dc9b545f309ea2b0e12/lua/blink/cmp/init.lua#L208-L213
          if not require("blink.cmp.completion.list").can_select() then
            return
          end
          vim.schedule(function()
            local page_size = vim.api.nvim_win_get_height(require("blink.cmp.completion.windows.menu").win:get_win())
            -- half page down
            require("blink.cmp.completion.list").select_next({ count = math.floor(page_size / 2) })
          end)
          return true
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
          if cmp.get_selected_item_idx() == nil or H.cmdline_actions.is_inserted(cmp) then
            return
          end
          -- work-around for insert current (selected) item
          cmp.select_next({ auto_insert = false })
          return cmp.select_prev({ auto_insert = true })
        end,
      }

      local ai_cmp = vim.g.ai_cmp
      function H.is_inline_cmp_possible()
        return not ai_cmp and vim.fn.win_gettype() ~= "command" and vim.bo.filetype ~= "copilot-chat"
      end

      return U.extend_tbl(opts, {
        appearance = {
          nerd_font_variant = "normal",
        },
        -- `keymap` configuration for command-line window goes here
        keymap = {
          ["<Tab>"] = {
            "snippet_forward",
            LazyVim.cmp.map({ "ai_nes", "ai_accept" }),
            function(cmp)
              if H.is_inline_cmp_possible() then
                -- we don't know whether Tab will select the next item or accept the inline completion
                return
              end
              return cmp.select_next() or H.actions.pum_next(cmp)
            end,
            function(cmp)
              if has_words_before() then
                return cmp.show()
              end
            end,
            function()
              -- the same behavior as normal buffer for command-line window
              if vim.fn.getcmdwintype() == ":" then
                vim.api.nvim_feedkeys(vim.keycode("<Tab>"), "n", false) -- insert a tab character
                return true -- do not fallback, which would open the popup menu ("q:")
              end
            end,
            "fallback",
          },
          ["<S-Tab>"] = {
            "snippet_backward",
            function(cmp)
              if H.is_inline_cmp_possible() then
                return
              end
              return cmp.select_prev() or H.actions.pum_prev(cmp)
            end,
            "fallback",
          },
          ["<Right>"] = {
            LazyVim.cmp.map({ "ai_accept" }), -- when there's an active snippet, we use <right> to accept the AI inline suggestion since <tab> is used for snippet jumping
            function(cmp)
              if cmp.is_ghost_text_visible() then
                return cmp.select_and_accept()
              end
            end,
            "fallback",
          },
          ["<CR>"] = { "accept", H.actions.pum_accept, "fallback" },
          ["<C-e>"] = {
            "cancel",
            function(cmp)
              if _G.MiniSnippets and MiniSnippets.session.get() then
                return H.actions.snippet_stop(cmp)
              end
            end,
            "fallback",
          },
          ["<C-n>"] = { "select_next", "show" },
          ["<C-p>"] = { "select_prev", "show" },
          ["<C-j>"] = { "select_next", H.actions.pum_next, "fallback" },
          ["<C-k>"] = { "select_prev", H.actions.pum_prev, "fallback" },
          ["<C-l>"] = { H.actions.mini_snippets_expand, "fallback" }, -- TODO: fallback is unreachable because H.actions.mini_snippets_expand always returns true
          -- ["<C-u>"] = { "scroll_documentation_up", "scroll_signature_up", "fallback" },
          -- ["<C-d>"] = { "scroll_documentation_down", "scroll_signature_down", "fallback" },
          ["<C-u>"] = { H.actions.scroll_list_up, "fallback" },
          ["<C-d>"] = { H.actions.scroll_list_down, "fallback" },
          ["<C-b>"] = { "scroll_documentation_up", "scroll_signature_up", "fallback" },
          ["<C-f>"] = { "scroll_documentation_down", "scroll_signature_down", "fallback" },
          ["<M-space>"] = { "show_signature", "hide_signature", "fallback" }, -- fallback seems unreachable because show_signature returns true if the signature is not visible
          ["<M-.>"] = {
            function(cmp)
              return cmp.select_next({ jump_by = "source_id" })
            end,
            "fallback",
          },
          ["<M-,>"] = {
            function(cmp)
              return cmp.select_prev({ jump_by = "source_id" })
            end,
            "fallback",
          },
        },
        cmdline = {
          keymap = {
            ["<CR>"] = {
              function(cmp)
                if cmp.is_menu_visible() and not H.cmdline_actions.is_inserted(cmp) then
                  return cmp.accept()
                end
              end,
              "fallback",
            },
            ["<Tab>"] = {
              "show_and_insert", -- show_and_insert_or_accept_single
              H.cmdline_actions.insert,
              "select_next",
            },
            -- TODO: check https://github.com/saghen/blink.cmp/commit/37ce860
            ["<S-Tab>"] = {
              "show_and_insert", -- show_and_insert_or_accept_single
              H.cmdline_actions.insert,
              "select_prev",
            },
            ["<Right>"] = {
              function(cmp)
                if cmp.is_ghost_text_visible() and not H.cmdline_actions.is_inserted(cmp) then
                  return cmp.select_and_accept()
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
            ["<C-u>"] = { H.actions.scroll_list_up, "fallback" },
            ["<C-d>"] = { H.actions.scroll_list_down, "fallback" },
            ["<C-space>"] = { "show", "hide" },
          },
          -- `completion` configuration for command-line window goes here
          completion = {
            menu = {
              auto_show = function()
                -- the same behavior as normal buffer for command-line window
                return vim.fn.getcmdtype() == ":" or vim.fn.getcmdwintype() == ":"
              end,
            },
            ghost_text = {
              enabled = function()
                local cmdwintype = vim.fn.getcmdwintype()
                if cmdwintype ~= "" then
                  -- For command-line window,
                  -- align `ghost_text` with the result of `:=LazyVim.opts("blink.cmp").cmdline.completion.menu.auto_show()` in command-line window,
                  -- because with `ghost_text` and `preselect` enabled in cmdwin, <cr> accepts the ghost text (preselected item) instead of executing the command-line.
                  return cmdwintype == ":"
                else
                  -- For command-line mode,
                  -- enable ghost_text when the cursor is at the end of cmdline, in favor of the `<>` pair of mini.pairs and the left arrow key
                  return vim.fn.getcmdpos() == #vim.fn.getcmdline() + 1
                end
              end,
            },
            list = {
              selection = {
                preselect = function()
                  -- enable preselect in cmdwin, the same behavior as in normal buffer
                  return vim.fn.win_gettype() == "command"
                end,
              },
            },
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
                  -- { "score" }, -- helpful for setting score_offset
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
                score = {
                  text = function(ctx)
                    return string.format("%d(%d)", ctx.item.score, ctx.item.score_offset)
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
      } --[[@as blink.cmp.Config]])
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
    "nvim-mini/mini.snippets",
    optional = true,
    opts = function(_, opts)
      LazyVim.cmp.actions.snippet_active = function()
        return MiniSnippets.session.get() ~= nil
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
        -- window = {
        --   show_documentation = not vim.g.user_is_termux,
        -- },
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
    dependencies = {
      "mikavilpas/blink-ripgrep.nvim",
      version = "*",
      shell_command_editor = true,
    },
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
              project_root_marker = function(_, path)
                return path == LazyVim.root({ normalize = true })
              end,
              backend = {
                use = "gitgrep-or-ripgrep",
                ripgrep = {
                  ignore_paths = { vim.uv.os_homedir() }, -- reduce CPU usage
                  project_root_fallback = false,
                },
              },
            },
          },
        },
      },
    },
  },

  -- {
  --   "saghen/blink.cmp",
  --   optional = true,
  --   dependencies = {
  --     "garyhurtz/blink_cmp_kitty",
  --     enabled = vim.g.user_is_kitty,
  --     shell_command_editor = true,
  --   },
  --   opts = vim.g.user_is_kitty and {
  --     sources = {
  --       default = { "blink_cmp_kitty" },
  --       providers = {
  --         blink_cmp_kitty = {
  --           module = "blink_cmp_kitty",
  --           name = "kitty",
  --           min_keyword_length = 3,
  --           max_items = 2,
  --           score_offset = -10,
  --         },
  --       },
  --     },
  --   } or nil,
  -- },

  -- {
  --   "gbprod/yanky.nvim",
  --   optional = true,
  --   specs = {
  --     {
  --       "saghen/blink.cmp",
  --       optional = true,
  --       dependencies = {
  --         "marcoSven/blink-cmp-yanky",
  --         shell_command_editor = true,
  --         init = function()
  --           LazyVim.on_load("mini.icons", function()
  --             require("snacks.util").set_hl({ BlinkCmpKindYank = "MiniIconsYellow" })
  --           end)
  --         end,
  --       },
  --       ---@type blink.cmp.Config
  --       opts = {
  --         sources = {
  --           default = { "yank" },
  --           providers = {
  --             yank = {
  --               module = "blink-yanky",
  --               min_keyword_length = 3,
  --               max_items = 1,
  --               score_offset = -10,
  --               opts = {
  --                 kind_icon = "󰅍",
  --               },
  --             },
  --           },
  --         },
  --       },
  --     },
  --   },
  -- },

  -- {
  --   "saghen/blink.cmp",
  --   optional = true,
  --   dependencies = { "ribru17/blink-cmp-spell", shell_command_editor = true },
  --   ---@type blink.cmp.Config
  --   opts = {
  --     sources = {
  --       default = { "spell" },
  --       providers = {
  --         spell = {
  --           module = "blink-cmp-spell",
  --           min_keyword_length = 2,
  --           max_items = 1,
  --           score_offset = -10,
  --           opts = {
  --             preselect_current_word = false,
  --             use_cmp_spell_sorting = true,
  --           },
  --         },
  --       },
  --     },
  --   },
  -- },

  -- {
  --   "saghen/blink.cmp",
  --   optional = true,
  --   dependencies = {
  --     "Kaiser-Yang/blink-cmp-dictionary",
  --     shell_command_editor = true,
  --     -- TODO: add dict downloading to build
  --     init = function()
  --       LazyVim.on_load("mini.icons", function()
  --         require("snacks.util").set_hl({ BlinkCmpKindDict = "MiniIconsRed" })
  --       end)
  --     end,
  --   },
  --   ---@type blink.cmp.Config
  --   opts = {
  --     sources = {
  --       default = { "dictionary" },
  --       providers = {
  --         dictionary = {
  --           module = "blink-cmp-dictionary",
  --           name = "Dict",
  --           min_keyword_length = 3,
  --           max_items = 1,
  --           score_offset = -20,
  --           ---@module 'blink-cmp-dictionary'
  --           ---@type blink-cmp-dictionary.Options
  --           opts = {
  --             dictionary_files = {
  --               -- aspell -d en_US dump master | aspell -l en expand | sed 's/\s\+/\n/g' > aspell_en.dict
  --               vim.fn.stdpath("data") .. "/cmp-dictionary/dict/aspell_en.dict",
  --               -- -- https://github.com/dwyl/english-words/blob/8179fe68775df3f553ef19520db065228e65d1d3/words_alpha.txt
  --               -- vim.fn.stdpath("data") .. "/cmp-dictionary/dict/words_alpha.txt",
  --             },
  --           },
  --         },
  --       },
  --     },
  --   },
  -- },
  -- {
  --   "saghen/blink.cmp",
  --   optional = true,
  --   dependencies = {
  --     "archie-judd/blink-cmp-words",
  --     shell_command_editor = true,
  --   },
  --   opts = {
  --     sources = {
  --       default = { "dictionary", "thesaurus" },
  --       providers = {
  --         dictionary = {
  --           module = "blink-cmp-words.dictionary",
  --           name = "Dict",
  --           min_keyword_length = 3,
  --           max_items = 1,
  --           ---@module 'blink-cmp-words'
  --           ---@type BlinkCmpWordsOpts|{}
  --           opts = {
  --             score_offset = -10, -- actually is -20, see: https://github.com/archie-judd/blink-cmp-words/blob/f6190f584075476ee9abd5aa736ef9085c9b2694/lua/blink-cmp-words/source.lua#L171
  --           },
  --         },
  --         thesaurus = {
  --           module = "blink-cmp-words.thesaurus",
  --           name = "Words",
  --           min_keyword_length = 3,
  --           max_items = 1,
  --           ---@type BlinkCmpWordsOpts|{}
  --           opts = {
  --             score_offset = -10,
  --           },
  --         },
  --       },
  --     },
  --   },
  -- },
  {
    "saghen/blink.cmp",
    dependencies = {
      "xieyonn/blink-cmp-dat-word",
      shell_command_editor = true,
    },
    opts = {
      sources = {
        default = { "datword" },
        providers = {
          datword = {
            name = "Word",
            module = "blink-cmp-dat-word",
            ---@module 'blink-cmp-dat-word'
            ---@type blink.cmp.Source.DatWord.Opts|{}
            opts = {
              paths = {
                require("lazy.core.config").options.root .. "/google-10000-english/google-10000-english-usa.txt",
                -- "/usr/share/dict/words", -- this file is included by default on Linux/macOS
              },
            },
            max_items = 1,
            score_offset = -10,
            min_keyword_length = 3,
          },
        },
      },
    },
    specs = {
      -- not a nvim plugin, just for downloading the dict file
      { "first20hours/google-10000-english", lazy = true },
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

            -- -- without trigger character
            -- min_keyword_length = 3,
            -- max_items = 3,
            -- score_offset = -25,

            -- with "$" as trigger character
            max_items = 20,
          },
        },
      },
    },
  },

  -- HACK: deduplicate items, see: https://github.com/Saghen/blink.cmp/issues/1222#issuecomment-2891921393
  {
    "saghen/blink.cmp",
    optional = true,
    opts = function()
      -- sources that need deduplicating
      -- :=LazyVim.opts("blink.cmp").sources.default
      local dedup_order = {
        "lazydev",
        "lsp",
        "path",
        "buffer",
        "ripgrep",
        "blink_cmp_kitty",
        "dictionary",
        "thesaurus",
        "datword",
        "spell",
        "yank",
      }

      local show_orig = require("blink.cmp.completion.list").show
      ---@diagnostic disable-next-line: duplicate-set-field
      require("blink.cmp.completion.list").show = function(ctx, items_by_source)
        local seen = {}
        for _, source in ipairs(dedup_order) do
          if items_by_source[source] then
            ---@param item blink.cmp.CompletionItem
            items_by_source[source] = vim.tbl_filter(function(item)
              local did_see = seen[item.label]
              seen[item.label] = true
              return not did_see
            end, items_by_source[source])
          end
        end
        return show_orig(ctx, items_by_source)
      end
    end,
  },

  -- nvim-cmp {{{

  -- use <tab> for completion and snippets (supertab)
  {
    "nvim-cmp",
    optional = true,
    ---@module "cmp"
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
