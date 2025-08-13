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
    init = function()
      LazyVim.on_very_lazy(function()
        LazyVim.format.register({
          name = "orgmode",
          priority = 0,
          primary = true,
          -- see:
          -- - https://github.com/nvim-orgmode/orgmode/blob/7ffb34c622e1c64323e56fdb571b775db021fec1/docs/configuration.org?plain=1#L2341-L2359
          -- - https://github.com/nvim-orgmode/orgmode/blob/27ab1cf9e7ae142f9e9ffb218be50dd920f04cb3/ftplugin/org.lua#L30
          format = function(buf)
            local tw = vim.bo[buf].textwidth
            vim.bo[buf].textwidth = 999 -- disable textwidth for gq, related to https://github.com/nvim-orgmode/orgmode/issues/144#issuecomment-965049864
            vim.api.nvim_buf_call(buf, function()
              local mode = vim.api.nvim_get_mode().mode
              if mode == "v" or mode == "V" then
                vim.cmd("normal! gq")
              else
                vim.cmd("lockmarks normal! zRmzgggqG`z")
                vim.cmd("delmarks z")
              end
            end)
            vim.bo[buf].textwidth = tw
          end,
          sources = function(buf)
            return vim.bo[buf].filetype == "org" and { "orgmode" } or {}
          end,
        })
      end)
    end,
  },
}
