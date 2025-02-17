return {
  { "tzachar/highlight-undo.nvim", optional = true, enabled = false },

  { "y3owk1n/undo-glow.nvim", optional = true, enabled = false },

  {
    "rachartier/tiny-glimmer.nvim",
    dependencies = {
      {
        "gbprod/yanky.nvim",
        optional = true,
        keys = { { "p", false }, { "P", false } },
        opts = { highlight = { on_yank = false, on_put = false } },
      },
    },
    event = {
      "TextYankPost",
      -- "WinEnter", -- for pulsar
    },
    keys = { { "p" }, { "P" }, { "u" }, { "U" }, { "<C-r>" } },
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

      vim.keymap.set("n", "U", "<C-r>", { remap = true, silent = true, desc = "Redo" })
      if LazyVim.has("yanky.nvim") then
        -- for tiny-glimmer.nvim to hijack
        vim.keymap.set("n", "p", "<Plug>(YankyPutAfter)")
        vim.keymap.set("n", "P", "<Plug>(YankyPutBefore)")
      end

      Snacks.util.set_hl({
        TinyGlimmerUndoFrom = "Substitute",
        TinyGlimmerRedoFrom = "TinyGlimmerUndoFrom",
        TinyGlimmerPulsarFrom = "Visual",
        TinyGlimmerPulsarTo = "Visual",
      })
      vim.api.nvim_create_autocmd("ColorScheme", {
        callback = function()
          for animation, hl in pairs(animations()) do
            require("tiny-glimmer").change_hl(animation, hl)
          end
        end,
      })

      return vim.tbl_deep_extend("force", opts, {
        overwrite = {
          search = { enabled = false },
          yank = { enabled = true },
          paste = { enabled = true },
          undo = {
            enabled = true,
            default_animation = {
              settings = {
                from_color = "TinyGlimmerUndoFrom",
              },
            },
          },
          redo = {
            enabled = true,
            default_animation = {
              settings = {
                from_color = "TinyGlimmerRedoFrom",
              },
            },
          },
        },
        presets = {
          pulsar = {
            enabled = false,
            on_event = { "WinEnter" },
            default_animation = {
              settings = {
                max_duration = 80,
                min_duration = 80,
                from_color = "TinyGlimmerPulsarFrom",
                to_color = "TinyGlimmerPulsarTo",
              },
            },
          },
        },
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
