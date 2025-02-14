return {
  -- https://github.com/mawkler/nvim/blob/30bd7ac8de8ff028c1c35a384d4eccdb49696f1a/lua/configs/tiny-glimmer.lua
  {
    "rachartier/tiny-glimmer.nvim",
    dependencies = {
      {
        "gbprod/yanky.nvim",
        optional = true,
        -- keys = { { "p", false }, { "P", false } },
        opts = {
          highlight = {
            on_yank = false,
            -- on_put = false,
          },
        },
      },
    },
    event = "TextYankPost",
    -- keys = { { "p" }, { "P" } },
    opts = function(_, opts)
      local function animations()
        local visual = Snacks.util.color("Visual", "bg")
        return {
          fade = {
            from_color = Snacks.util.color("CurSearch", "bg"),
            to_color = visual,
          },
          reverse_fade = {
            from_color = U.color.darken(Snacks.util.color("FlashLabel", "bg"), 0.5),
            to_color = visual,
          },
        }
      end

      vim.api.nvim_create_autocmd("ColorScheme", {
        callback = function()
          for animation, hl in pairs(animations()) do
            require("tiny-glimmer").change_hl(animation, hl)
          end
        end,
      })

      -- local has_yanky = LazyVim.has("yanky.nvim")

      return U.extend_tbl(opts, {
        overwrite = {
          -- TODO: kevinhwang91/nvim-hlslens integration
          search = { enabled = false },
          paste = {
            -- TODO: https://github.com/rachartier/tiny-glimmer.nvim/issues/21
            enabled = false,
            -- paste_mapping = has_yanky and "<Plug>(YankyPutAfter)" or "p",
            -- Paste_mapping = has_yanky and "<Plug>(YankyPutBefore)" or "P",
          },
        },
        transparency_color = vim.g.user_transparent_background and "#000000" or nil,
        animations = animations(),
      })
    end,
    init = function()
      vim.api.nvim_create_autocmd("User", {
        pattern = "LazyVimAutocmdsDefaults",
        callback = function()
          vim.api.nvim_del_augroup_by_name("lazyvim_highlight_yank")
        end,
      })
    end,
  },
}
