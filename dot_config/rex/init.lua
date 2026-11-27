require("keys")
require("smart_splits")
require("copy_mode")

-- https://www.superlogical.com/rex/docs/customize/resume-rules#example-neovim-sessions
rex.set("resume.trust.nvim", {
  command = { "nvim", "-S", rex.match.under("~/.local/state/nvim/sessions") },
})
