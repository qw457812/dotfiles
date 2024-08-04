return {
  -- https://github.com/liubang/nvimrc/blob/e7dbb3f5193728b59dbfff5dcd5b3756c5ed1585/lua/plugins/neo-tree-nvim.lua
  -- https://github.com/Matt-FTW/dotfiles/blob/main/.config/nvim/lua/plugins/extras/editor/neo-tree-extended.lua
  -- https://github.com/GentleCold/dotfiles/blob/5104ac8fae45b68a33c973a19b1f6a2e0617d400/.config/nvim/lua/plugins/dir_tree.lua
  -- https://github.com/nvim-lua/kickstart.nvim/blob/master/lua/kickstart/plugins/neo-tree.lua
  -- https://github.com/rafi/vim-config/blob/b9648dcdcc6674b707b963d8de902627fbc887c8/lua/rafi/plugins/neo-tree.lua
  -- https://github.com/aimuzov/LazyVimx/blob/789dafed84f6f61009f13b4054f12208842df225/lua/lazyvimx/extras/ui/panels/explorer.lua
  {
    "nvim-neo-tree/neo-tree.nvim",
    keys = function(_, keys)
      LazyVim.toggle.map("<leader>uz", {
        name = "NeoTree Auto Close",
        get = function()
          return vim.g.user_neotree_auto_close
        end,
        set = function(state)
          vim.g.user_neotree_auto_close = state
          if state then
            require("neo-tree.command").execute({ action = "close" })
          end
        end,
      })

      local mappings = {
        --[[add custom keys here]]
      }

      local opts = LazyVim.opts("neo-tree.nvim")
      if opts.filesystem.hijack_netrw_behavior ~= "disabled" then
        vim.list_extend(mappings, {
          -- make the `-` key reveal the current file, or if in an unsaved file, the current working directory
          -- :h neo-tree-configuration
          {
            "-",
            function()
              local reveal_file = vim.fn.expand("%:p")
              if reveal_file == "" then
                reveal_file = vim.fn.getcwd()
              else
                local f = io.open(reveal_file, "r")
                if f then
                  f.close(f)
                else
                  reveal_file = vim.fn.getcwd()
                end
              end
              require("neo-tree.command").execute({
                action = "focus", -- OPTIONAL, this is the default value
                source = "filesystem", -- OPTIONAL, this is the default value
                position = "left", -- OPTIONAL, this is the default value
                reveal_file = reveal_file, -- path to file or folder to reveal
                reveal_force_cwd = true, -- change cwd without asking if needed
              })
            end,
            desc = "Open neo-tree at current file or working directory",
          },
        })
      end
      return vim.list_extend(mappings, keys)
    end,
    opts = {
      close_if_last_window = true, -- close Neo-tree if it is the last window left in the tab
      commands = {
        unfocus_window = function(state)
          if state.current_position == "left" then
            vim.cmd("wincmd l")
          end
        end,
        close_or_unfocus_window = function(state)
          state.commands[vim.g.user_neotree_auto_close and "close_window" or "unfocus_window"](state)
        end,
      },
      window = {
        mappings = {
          ["-"] = "close_or_unfocus_window", -- toggle neo-tree, work with `-` defined in `keys` above
          -- ["<bs>"] = "none", -- see: close.lua
          ["<tab>"] = {
            function(state)
              local node = state.tree:get_node()
              if require("neo-tree.utils").is_expandable(node) then
                state.commands["toggle_node"](state)
              else
                state.commands["open"](state)
                vim.cmd("Neotree reveal")
              end
            end,
            desc = "Open without focus",
          },
        },
      },
      filesystem = {
        filtered_items = {
          hide_dotfiles = false,
          hide_gitignored = false,
          hide_hidden = false,
          hide_by_name = {
            -- "node_modules",
            -- ".git",
          },
          never_show = {
            ".DS_Store",
            "thumbs.db",
          },
        },
        -- whether to use for editing directories (e.g. `vim .` or `:e src/`)
        -- possible values: "open_default" (default), "open_current", "disabled"
        -- hijack_netrw_behavior = "disabled", -- netrw left alone, neo-tree does not handle opening dirs
        window = {
          -- TODO: unify the keybindings of https://github.com/vifm/vifm and neo-tree.nvim (or telescope-file-browser.nvim)
          -- https://github.com/craftzdog/dotfiles-public/blob/bf837d867b1aa153cbcb2e399413ec3bdcce112b/.config/nvim/lua/plugins/editor.lua#L58
          -- https://github.com/jacquin236/minimal-nvim/blob/baacb78adce67d704d17c3ad01dd7035c5abeca3/lua/plugins/editor/telescope-extras.lua#L3
          mappings = {
            -- https://github.com/nvim-neo-tree/neo-tree.nvim/wiki/Tips#navigation-with-hjkl
            -- TODO: same behavior hjkl navigation, <esc> unfocus for buffers and git_status
            ["h"] = {
              function(state)
                local node = state.tree:get_node()
                if node.type == "directory" and node:is_expanded() and node:has_children() then
                  require("neo-tree.sources.filesystem").toggle_directory(state, node)
                elseif node:get_depth() == 1 then
                  require("neo-tree.sources.filesystem.commands").navigate_up(state)
                else
                  require("neo-tree.ui.renderer").focus_node(state, node:get_parent_id())
                end
              end,
              desc = "focus parent / close_node / navigate_up",
            },
            ["l"] = {
              function(state)
                local node = state.tree:get_node()
                if node.type == "directory" then
                  if not node:is_expanded() then
                    require("neo-tree.sources.filesystem").toggle_directory(state, node)
                  elseif node:has_children() then
                    require("neo-tree.ui.renderer").focus_node(state, node:get_child_ids()[1])
                  end
                else
                  require("neo-tree.sources.filesystem.commands").open(state)
                end
              end,
              desc = "expand node / focus first child / open",
            },
            -- ["<esc>"] = {
            --   function(state)
            --     require("neo-tree.sources.common.commands").cancel(state) -- close preview or floating neo-tree window
            --     require("neo-tree.sources.filesystem.commands").clear_filter(state)
            --   end,
            --   desc = "cancel + clear_filter",
            -- },
            ["<esc>"] = {
              function(state)
                local preview = require("neo-tree.sources.common.preview")
                -- copied from: https://github.com/nvim-neo-tree/neo-tree.nvim/blob/206241e451c12f78969ff5ae53af45616ffc9b72/lua/neo-tree/sources/common/commands.lua#L653
                local has_preview = preview.is_active()
                local has_floating = state.current_position == "float"
                local has_filter = state.search_pattern ~= nil
                if has_preview or has_floating or has_filter then
                  -- original behavior of <esc> is `cancel`: close preview or floating neo-tree window
                  -- require("neo-tree.sources.common.commands").cancel(state)
                  if has_preview then
                    preview.hide()
                  end
                  if has_floating then
                    require("neo-tree.ui.renderer").close_all_floating_windows()
                  end
                  if has_filter then
                    require("neo-tree.sources.filesystem.commands").clear_filter(state)
                  end
                else
                  -- close_or_unfocus_window if nothing to do
                  state.commands["close_or_unfocus_window"](state)
                end
              end,
              desc = "(cancel + clear_filter) / close_or_unfocus_window",
            },
          },
        },
      },
      buffers = {
        window = {
          mappings = {
            ["bd"] = "none", -- use `d` instead
            ["d"] = "buffer_delete",
          },
        },
      },
      event_handlers = {
        -- https://github.com/nvim-neo-tree/neo-tree.nvim/wiki/Recipes#auto-close-on-open-file
        -- alternative: https://github.com/nvim-neo-tree/neo-tree.nvim/issues/344
        {
          event = "file_opened",
          handler = function(file_path)
            if vim.g.user_neotree_auto_close then
              -- auto close on open file
              require("neo-tree.command").execute({ action = "close" })
            end
          end,
        },
      },
    },
  },

  -- {
  --   "folke/which-key.nvim",
  --   opts = {
  --     -- preset = "modern",
  --     -- win = {
  --     --   no_overlap = false, -- don't allow the popup to overlap with the cursor
  --     -- },
  --   },
  -- },

  -- {
  --   "RRethy/vim-illuminate",
  --   optional = true,
  --   opts = function()
  --     -- base on tokyonight-moon
  --     local illuminate = "#51576d"
  --     -- remove `default = true,` to override colorscheme's highlight group
  --     vim.api.nvim_set_hl(0, "IlluminatedWordText", { default = true, bg = "#3b4261" })
  --     vim.api.nvim_set_hl(0, "IlluminatedWordRead", { default = true, bg = illuminate })
  --     vim.api.nvim_set_hl(0, "IlluminatedWordWrite", { default = true, bg = illuminate, underline = true })
  --   end,
  -- },

  -- for escaping easily from insert mode
  {
    "max397574/better-escape.nvim",
    event = "VeryLazy",
    opts = {
      -- note: lazygit, fzf-lua use terminal mode, `jj` and `jk` make lazygit navigation harder
      default_mappings = false,
      mappings = {
        i = {
          j = {
            -- these can all also be functions
            k = "<Esc>",
            j = "<Esc>",
          },
          k = {
            j = "<Esc>",
          },
        },
        c = {
          j = {
            k = "<Esc>",
            j = "<Esc>",
          },
          k = {
            j = "<Esc>",
          },
        },
      },
    },
  },

  -- TODO: choose motion plugin between: flash, leap, hop
  -- https://github.com/doctorfree/nvim-lazyman/blob/bb4091c962e646c5eb00a50eca4a86a2d43bcb7c/lua/ecovim/config/plugins.lua#L373
}
