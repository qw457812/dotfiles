---@type LazySpec
return {
  {
    "NeogitOrg/neogit",
    cmd = "Neogit",
    keys = function()
      ---@param opts OpenOpts|nil
      local open = function(opts)
        opts = vim.tbl_deep_extend("force", { cwd = LazyVim.root.git() }, opts or {})
        require("neogit").open(opts)
      end

      return {
        { "<Leader>gn", open, desc = "Neogit (Root Dir)" },
        { "<Leader>gN", "<Cmd>Neogit<CR>", desc = "Neogit (cwd)" },
        {
          "<Leader>gc",
          function()
            open({ "commit" })

            -- skip NeogitPopup
            local executed = false
            local id = vim.api.nvim_create_autocmd("FileType", {
              group = vim.api.nvim_create_augroup("neogit_quick_commit", { clear = true }),
              pattern = "NeogitPopup",
              once = true,
              callback = function()
                executed = true
                vim.api.nvim_feedkeys("c", "m", false)
              end,
            })
            vim.defer_fn(function()
              if not executed then -- see `:h autocmd-once`
                vim.api.nvim_del_autocmd(id)
              end
            end, 500)
          end,
          desc = "Commit (Neogit)",
        },
      }
    end,
    opts = function(_, opts)
      vim.api.nvim_create_autocmd("FileType", {
        group = vim.api.nvim_create_augroup("neogit_commit_diff_keymaps", { clear = true }),
        pattern = "NeogitDiffView", -- for `:Neogit commit`
        callback = function(ev)
          local buf = ev.buf
          -- stylua: ignore
          vim.keymap.set("n", "<Esc>", U.keymap.clear_ui_or_unfocus_esc, { buffer = buf, desc = "Clear UI or Unfocus (Neogit)" })
          vim.keymap.set("n", "]h", "}", { buffer = buf, remap = true, desc = "Next Hunk (Neogit)" })
          vim.keymap.set("n", "[h", "{", { buffer = buf, remap = true, desc = "Prev Hunk (Neogit)" })
          vim.defer_fn(function()
            if not vim.api.nvim_buf_is_valid(buf) then
              return
            end
            pcall(vim.keymap.del, "n", "<Tab>", { buffer = buf }) -- <Tab> is mapped to <C-w>w
          end, 100)
        end,
      })

      return U.extend_tbl(opts, {
        disable_signs = true,
        telescope_sorter = function()
          if LazyVim.has("telescope-fzf-native.nvim") then
            return require("telescope").extensions.fzf.native_fzf_sorter()
          end
        end,
        integrations = {
          -- diffview = LazyVim.has("diffview.nvim"),
          telescope = LazyVim.pick.picker.name == "telescope",
          fzf_lua = LazyVim.pick.picker.name == "fzf",
          snacks = LazyVim.pick.picker.name == "snacks",
        },
      })
    end,
    specs = {
      {
        "catppuccin",
        optional = true,
        opts = { integrations = { neogit = true } },
      },
    },
  },
}
