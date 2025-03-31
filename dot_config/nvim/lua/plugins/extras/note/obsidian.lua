local obsidian_vaults = {
  personal = U.path.HOME .. "/Documents/vaults/personal",
  work = U.path.HOME .. "/Documents/vaults/work",
}

return {
  {
    "obsidian-nvim/obsidian.nvim",
    enabled = not vim.g.user_is_termux,
    event = (function()
      local events = {}
      for _, path in pairs(obsidian_vaults) do
        table.insert(events, "BufReadPre " .. path .. "/*.md")
        table.insert(events, "BufNewFile " .. path .. "/*.md")
      end
      return events
    end)(),
    opts = function()
      local workspaces = {}
      for name, path in pairs(obsidian_vaults) do
        table.insert(workspaces, { name = name, path = path })
      end

      return {
        -- https://github.com/MeanderingProgrammer/render-markdown.nvim#obsidiannvim
        ui = { enable = not LazyVim.has("render-markdown.nvim") },
        workspaces = workspaces,
        completion = {
          nvim_cmp = LazyVim.has_extra("coding.nvim-cmp"),
          blink = LazyVim.has("blink.cmp"),
        },
        picker = {
          name = ({ snacks = "snacks.pick", fzf = "fzf-lua", telescope = "telescope.nvim" })[LazyVim.pick.picker.name],
        },
      }
    end,
  },
}
