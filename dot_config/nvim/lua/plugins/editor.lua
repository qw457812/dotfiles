return {
  -- for escaping easily from insert mode with jk/jj
  { "max397574/better-escape.nvim", event = "InsertCharPre", opts = { timeout = 300 } },
}
