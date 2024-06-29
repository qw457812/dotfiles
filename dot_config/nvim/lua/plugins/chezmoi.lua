-- require lazyvim.plugins.extras.util.chezmoi
return {
  {
    "xvzc/chezmoi.nvim",
    optional = true,
    keys = {
      { "<leader>sz", false },
      {
        "<leader>f.",
        function()
          if LazyVim.pick.picker.name == "telescope" then
            require("telescope").extensions.chezmoi.find_files()
          elseif LazyVim.pick.picker.name == "fzf" then
            require("fzf-lua").fzf_exec(require("chezmoi.commands").list({}), {
              actions = {
                ["default"] = function(selected)
                  require("chezmoi.commands").edit({
                    targets = { "~/" .. selected[1] },
                    args = { "--watch" },
                  })
                end,
              },
            })
          end
        end,
        desc = "Find Chezmoi Source Dotfiles",
      },
    },
  },
}
