return {
  {
    "mcauley-penney/visual-whitespace.nvim",
    event = "ModeChanged *:[vV\x16]*",
    opts = function()
      Snacks.util.set_hl({
        VisualNonText = {
          fg = U.color.darken(Snacks.util.color("Comment"), 0.8),
          bg = Snacks.util.color("Visual", "bg"),
        },
      })

      return {
        nl_char = "",
      }
    end,
  },
}
