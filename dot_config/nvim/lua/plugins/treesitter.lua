---@type LazySpec
return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        ts_query_ls = not vim.g.user_is_termux and {} or nil,
      },
    },
  },

  {
    "nvim-treesitter/nvim-treesitter",
    ---@type lazyvim.TSConfig|{}
    opts = { ensure_installed = { "jq", "awk", "mermaid", "groovy", "promql" } },
  },
  {
    "nvim-treesitter/nvim-treesitter",
    keys = {
      { "<leader>it", vim.cmd.TSInfo, desc = "Treesitter" },
    },
    ---@module "lazyvim"
    ---@param opts lazyvim.TSConfig
    opts = function(_, opts)
      -- Setup highlight on our own in favor of chezmoi templates
      opts.highlight.enable = false
      local has_chezmoi_vim = LazyVim.has("chezmoi.vim")
      vim.api.nvim_create_autocmd("FileType", {
        callback = function(ev)
          if
            LazyVim.treesitter.have(ev.match, "highlights")
            and not (has_chezmoi_vim and ev.match:find("chezmoitmpl"))
          then
            pcall(vim.treesitter.start, ev.buf)
          end
        end,
      })

      vim.api.nvim_create_user_command("TSInfo", function()
        local TS = require("nvim-treesitter")

        -- `:=LazyVim.opts("nvim-treesitter").ensure_installed`
        local available, installed = TS.get_available(), TS.get_installed("parsers")
        local not_installed = vim.tbl_filter(function(p)
          return not vim.list_contains(installed, p)
        end, available)

        local function format_parsers(parsers)
          return table.concat(
            vim.tbl_map(function(p)
              return "`" .. p .. "`"
            end, parsers),
            ", "
          )
        end

        LazyVim.info(
          ("- Installed: %s\n- Not installed: %s"):format(format_parsers(installed), format_parsers(not_installed)),
          { title = ("Treesitter Installed (%d/%d)"):format(#installed, #available) }
        )
      end, { desc = "Show treesitter parsers info" })
    end,
  },

  {
    "OXY2DEV/helpview.nvim",
    ft = "help",
    dependencies = {
      "nvim-treesitter/nvim-treesitter",
      opts = { ensure_installed = { "vimdoc" } },
    },
    keys = {
      { "<leader>uH", "<cmd>Helpview Toggle<cr>", desc = "Helpview" },
    },
    ---@type helpview.config|{}
    opts = {
      preview = {
        icon_provider = "mini",
      },
    },
    config = function(_, opts)
      require("helpview").setup(opts)

      vim.api.nvim_create_autocmd("FileType", {
        group = vim.api.nvim_create_augroup("helpview_fix_lazy", { clear = true }),
        pattern = "help",
        once = true,
        callback = function()
          vim.cmd("Helpview attach")
        end,
      })
    end,
  },

  {
    "fei6409/log-highlight.nvim",
    event = "BufRead *.log",
    ft = "log",
    opts = {},
  },
}
