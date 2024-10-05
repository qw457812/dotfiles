if not LazyVim.has_extra("lang.markdown") then
  return {}
end

return {
  {
    "MeanderingProgrammer/render-markdown.nvim",
    optional = true,
    opts = {
      win_options = {
        -- toggling this plugin should also toggle conceallevel
        conceallevel = { default = 0 },
      },
    },
  },
}
