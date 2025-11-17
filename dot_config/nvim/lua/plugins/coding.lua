---@type LazySpec
return {
  {
    "nvim-mini/mini.pairs",
    optional = true,
    opts = function(_, opts)
      local pairs = require("mini.pairs")

      -- fix `=vim.fn.winnr(<cr>)` by '(' with `register = { cr = true }`
      vim.api.nvim_create_autocmd("CmdWinEnter", {
        callback = function(ev)
          vim.keymap.set("i", "<cr>", "<cr>", { buffer = ev.buf })
        end,
      })

      -- `<>` pair
      local lt_opts = { action = "open", pair = "<>", neigh_pattern = "[^\\].", register = { cr = false } }
      local gt_opts = { action = "close", pair = "<>", neigh_pattern = "[^\\].", register = { cr = false } }
      local angle_brackets_group = vim.api.nvim_create_augroup("mini_pairs_angle_brackets", { clear = true })
      -- use case for cmdline: `:map <esc>`
      local lt_opts_cmdline, gt_opts_cmdline = lt_opts, gt_opts
      pairs.map("c", "<", lt_opts_cmdline)
      pairs.map("c", ">", gt_opts_cmdline)
      vim.api.nvim_create_autocmd("CmdWinEnter", {
        group = angle_brackets_group,
        callback = function(ev)
          pairs.map_buf(ev.buf, "i", "<", lt_opts_cmdline)
          pairs.map_buf(ev.buf, "i", ">", gt_opts_cmdline)
        end,
      })
      -- use cases for lua:
      -- - `---@type table<string, string>`
      -- - `local z = x < y`
      -- see: https://www.reddit.com/r/neovim/comments/1kbz9jf/comment/mpzjc7k/
      vim.api.nvim_create_autocmd("FileType", {
        group = angle_brackets_group,
        pattern = { "lua", "java" },
        callback = function(ev)
          -- stylua: ignore
          pairs.map_buf(ev.buf, "i", "<", { action = "open", pair = "<>", neigh_pattern = "%a.", register = { cr = false } })
          pairs.map_buf(ev.buf, "i", ">", gt_opts)
        end,
      })
      -- use case for xml: `<?xml version="1.0"?>`
      vim.api.nvim_create_autocmd("FileType", {
        group = angle_brackets_group,
        pattern = "xml",
        callback = function(ev)
          pairs.map_buf(ev.buf, "i", "<", lt_opts)
          pairs.map_buf(ev.buf, "i", ">", gt_opts)
        end,
      })

      return U.extend_tbl(opts, {
        mappings = {
          ["`"] = { neigh_pattern = "[^\\`]." }, -- better deal with markdown code blocks in non-markdown files
        },
      })
    end,
  },

  {
    "nvim-mini/mini.surround",
    optional = true,
    keys = {
      { "m<C-n>", "<Cmd>lua MiniSurround.update_n_lines()<CR>", desc = "Update `MiniSurround.config.n_lines`" },
    },
    opts = function(_, opts)
      vim.api.nvim_create_autocmd("FileType", {
        pattern = "markdown",
        callback = function(ev)
          -- copied from: https://github.com/nvim-mini/MiniMax/blob/515c6ea7361ab11d8f6024e35b4068b06e528aed/configs/nvim-0.11/after/ftplugin/markdown.lua#L27-L42
          vim.b[ev.buf].minisurround_config = {
            custom_surroundings = {
              L = {
                input = { "%[().-()%]%(.-%)" },
                output = function()
                  local link = require("mini.surround").user_input("Link: ")
                  return { left = "[", right = "](" .. link .. ")" }
                end,
              },
            },
          }
        end,
      })

      if vim.tbl_get(opts, "mappings", "update_n_lines") then
        opts.mappings.update_n_lines = nil
      end
      return U.extend_tbl(opts, {
        -- helix-style mappings
        mappings = {
          add = "ms",
          replace = "mr",
          delete = "md",
          find = "",
          find_left = "",
          highlight = "",
        },
      })
    end,
  },
  {
    "folke/which-key.nvim",
    opts = {
      spec = {
        {
          mode = { "n", "x" },
          { "m", group = "match/surround" },
        },
      },
    },
  },

  {
    "nvim-mini/mini.ai",
    optional = true,
    opts = function(_, opts)
      local ai = require("mini.ai")
      return U.extend_tbl(opts, {
        mappings = {
          around_next = "",
          inside_next = "",
          around_last = "",
          inside_last = "",
          goto_left = "",
          goto_right = "",
        },
        custom_textobjects = {
          -- add `<>` brackets, copied from: https://github.com/nvim-mini/mini.ai/blob/7f1fe86277f0e977642cf8fe15f004229f61e61a/lua/mini/ai.lua#L1155
          ["b"] = { { "%b()", "%b[]", "%b{}", "%b<>" }, "^.().*().$" },
          ["?"] = false,
          ["/"] = ai.gen_spec.user_prompt(),
        },
      })
    end,
  },

  {
    "folke/lazydev.nvim",
    opts = function(_, opts)
      opts.library = opts.library or {}
      table.insert(opts.library, { path = "lazy.nvim", words = { "LazySpec" } })
    end,
  },

  {
    "gbprod/yanky.nvim",
    dependencies = { "kkharji/sqlite.lua", vscode = true, pager = true, shell_command_editor = true },
    optional = true,
    keys = {
      { "gp", mode = { "n", "x" }, false },
      { "gP", mode = { "n", "x" }, false },
    },
    opts = {
      ring = {
        storage = "sqlite",
      },
    },
  },

  {
    "Wansmer/treesj",
    vscode = true,
    keys = {
      { "<leader>J", "<cmd>TSJToggle<cr>", desc = "Join Toggle" },
    },
    opts = {
      use_default_keymaps = false,
      max_join_length = 150,
    },
  },

  {
    "chrisgrieser/nvim-various-textobjs",
    pager = true,
    shell_command_editor = true,
    vscode = true,
    keys = function()
      -- taken from: https://github.com/nvim-mini/mini.operators/blob/59f5fdbaaed7cce160076e70926cb16faadea78c/lua/mini/operators.lua#L705-L711
      local remap_builtin_gx = function(mode)
        if vim.fn.maparg("gX", mode) ~= "" then
          return
        end
        local keymap = vim.fn.maparg("gx", mode, false, true)
        local rhs = keymap.callback or keymap.rhs
        if rhs == nil or (keymap.desc or ""):find("URI under cursor") == nil then
          return
        end
        vim.keymap.set(mode, "gX", rhs, { desc = keymap.desc })
      end
      remap_builtin_gx("n")

      local keys = {
        {
          "gx",
          function()
            -- short url of lazy plugin
            if vim.bo.filetype == "lua" then
              local path = vim.fn.expand("%:p")
              if
                vim.fn.fnamemodify(path, ":t") == ".lazy.lua"
                or path:match("^" .. vim.pesc(U.path.CONFIG) .. "/lua/plugins/")
                or (U.path.CHEZMOI and path:match("^" .. vim.pesc(vim.fn.stdpath("config")) .. "/lua/plugins/"))
                or path:match("^" .. vim.pesc(U.path.LAZYVIM) .. "/lua/lazyvim/plugins/")
              then
                local lazy_plugin = vim.api.nvim_get_current_line():match("['\"]([%w%-%.]+/[%w%-%.]+)['\"]")
                local url = require("vim.ui")._get_urls()[1] -- ref: https://github.com/neovim/neovim/blob/520568f40f22d77e623ddda77cf751031774384b/runtime/lua/vim/_defaults.lua#L487-L492
                if lazy_plugin and not (url and vim.startswith(url, "http")) then
                  U.open_in_browser(("https://github.com/%s.git"):format(lazy_plugin))
                  return
                end
              end
            end

            require("various-textobjs").url()
            local found_url = vim.fn.mode() == "v"
            if found_url then
              local url = assert(U.get_visual_selection())
              U.open_in_browser(url)
              return
            end

            if U.is_bigfile() then
              return
            end
            -- find all URLs in buffer
            local url_patterns = require("various-textobjs.config.config").config.textobjs.url.patterns
            local buf_text = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
            local urls = {}
            for _, url_pattern in ipairs(url_patterns) do
              for url in buf_text:gmatch(url_pattern) do
                table.insert(urls, url)
              end
            end
            if #urls == 0 then
              return
            end
            -- select one
            vim.ui.select(urls, { prompt = "Select URL:" }, function(choice)
              if choice then
                U.open_in_browser(choice)
              end
            end)
          end,
          desc = "URL Opener",
        },
        {
          "mdi", -- mini.surround
          function()
            -- select outer indentation
            require("various-textobjs").indentation("outer", "outer")
            -- plugin only switches to visual mode when a textobj has been found
            local indentation_found = vim.fn.mode():find("V")
            if not indentation_found then
              return
            end

            -- dedent indentation
            vim.cmd.normal({ "<", bang = true })
            -- delete surrounding lines
            local end_border_ln = vim.api.nvim_buf_get_mark(0, ">")[1]
            local start_border_ln = vim.api.nvim_buf_get_mark(0, "<")[1]
            vim.cmd(tostring(end_border_ln) .. " delete") -- delete end first so line index is not shifted
            vim.cmd(tostring(start_border_ln) .. " delete")
          end,
          desc = "Delete Surrounding Indentation",
        },
        { "U", [[<cmd>lua require("various-textobjs").url()<CR>]], mode = { "o", "x" }, desc = "url" }, -- conflict with gUU
      }
      vim.keymap.set("n", "gUU", "gUU") -- prevent `omap U` from overwriting `gUU`

      -- stylua: ignore
      local ai_textobjs = {
        { name = "chainMember",          map = "m", desc = "chain member .foo(param)" }, -- map = "."
        { name = "key",                  map = "k", desc = "key-value, assignment" },
        { name = "value",                map = "v", desc = "key-value, assignment" },
        { name = "url",                  map = "l", desc = "url link" },
        -- markdown
        { name = "mdLink",               map = "l", desc = "md link [title](url)",   ft = "markdown" },
        { name = "mdFencedCodeBlock",    map = "C", desc = "md code block ```",      ft = "markdown" },
        { name = "mdEmphasis",           map = "E", desc = "md emphasis *_~=",       ft = "markdown" },
        -- python
        { name = "pyTripleQuotes",       map = "y", desc = [[py triple quotes """]], ft = "python" },
        -- lua, shell, org, neorg, markdown
        { name = "doubleSquareBrackets", map = "D", desc = "[[]] block",             ft = { "lua", "sh", "bash", "zsh", "fish", "org", "norg", "markdown" } },
        -- shell
        { name = "shellPipe",            map = "P", desc = "shell pipe |",           ft = { "sh", "bash", "zsh", "fish" } },
      }

      for _, tobj in ipairs(ai_textobjs) do
        -- stylua: ignore
        vim.list_extend(keys, {
          { "a" .. tobj.map, [[<cmd>lua require("various-textobjs").]] .. tobj.name .. [[("outer")<CR>]], mode = { "o", "x" }, desc = tobj.desc, ft = tobj.ft },
          { "i" .. tobj.map, [[<cmd>lua require("various-textobjs").]] .. tobj.name .. [[("inner")<CR>]], mode = { "o", "x" }, desc = tobj.desc, ft = tobj.ft },
        })
      end
      return keys
    end,
  },
  {
    "folke/which-key.nvim",
    opts = {
      spec = {
        { "gx", desc = "URL Opener" },
      },
    },
  },

  -- https://github.com/yutkat/dotfiles/blob/a80b83c66c8e2b8fab68b32486a1a02afd3adddb/.config/nvim/lua/rc/pluginconfig/text-case.lua#L14
  {
    "johmsalas/text-case.nvim",
    enabled = false, -- using gregorias/coerce.nvim
    vscode = true,
    keys = function()
      local keys = {
        { "ga" },
        { "gar", ":Subs/", mode = { "n", "x" }, desc = "Subs" },
      }
      if LazyVim.has("telescope.nvim") or vim.g.vscode then
        keys[#keys + 1] = { "gaa", "<cmd>TextCaseOpenTelescope<CR>", mode = { "n", "x" }, desc = "Telescope" }
      end
      return keys
    end,
    opts = {},
    config = function(_, opts)
      require("textcase").setup(opts)
      if LazyVim.has("telescope.nvim") then
        LazyVim.on_load("telescope.nvim", function()
          require("telescope").load_extension("textcase")
        end)
      end
    end,
  },
  {
    "gregorias/coerce.nvim",
    dependencies = "gregorias/coop.nvim",
    keys = {
      { "gaa", mode = { "n", "v" } },
    },
    ---@module 'coerce'
    ---@type CoerceConfigUser
    opts = {
      default_mode_keymap_prefixes = {
        normal_mode = "gaa", -- TODO: better keymap
        visual_mode = "gaa",
      },
      default_mode_mask = {
        motion_mode = false,
      },
    },
  },

  {
    "dmtrKovalenko/caps-word.nvim",
    keys = {
      { "<A-c>", "<cmd>lua require('caps-word').toggle()<CR>", mode = { "i", "n" }, desc = "Toggle Caps Word" },
    },
    opts = {
      enter_callback = function()
        vim.notify("Caps Word: On", vim.log.levels.INFO, { title = "Caps Word" })
      end,
      exit_callback = function()
        vim.notify("Caps Word: Off", vim.log.levels.INFO, { title = "Caps Word" })
      end,
    },
  },
}
