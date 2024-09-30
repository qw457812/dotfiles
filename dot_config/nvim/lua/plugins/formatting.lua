return {
  {
    "echasnovski/mini.align",
    vscode = true,
    opts = {
      mappings = {
        start = "", -- disabled since text-case.nvim uses `ga`
        start_with_preview = "gA",
      },
    },
    keys = {
      -- { "ga", mode = { "n", "v" }, desc = "Align" },
      { "gA", mode = { "n", "v" }, desc = "Align with Preview" },
    },
  },
}
