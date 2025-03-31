return {
  -- https://github.com/nvim-orgmode/orgmode/blob/master/DOCS.md#mappings
  {
    "nvim-orgmode/orgmode",
    ft = { "org", "orgagenda" },
    cmd = "Org",
    keys = {
      { "gA", '<Cmd>lua require("orgmode").action("agenda.prompt")<CR>', desc = "org agenda" },
      { "gC", '<Cmd>lua require("orgmode").action("capture.prompt")<CR>', desc = "org capture" },
    },
    opts = {
      org_agenda_files = "~/org/**/*",
      org_default_notes_file = "~/org/refile.org",
      mappings = {
        -- disable_all = true,
        global = {
          org_agenda = false,
          org_capture = false,
        },
        prefix = "<localleader>",
      },
    },
  },
}
