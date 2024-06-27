# 💤 LazyVim

> A [starter template](https://github.com/LazyVim/starter) for [LazyVim](https://github.com/LazyVim/LazyVim).\
> Refer to the [documentation](https://lazyvim.github.io/installation) to get started.

Using this [commit](https://github.com/LazyVim/starter/commit/cb79b0e6a9d0ec81041150dc87fe47352a54a2ba).

## Chezmoi Symlinks

- [lazyvim.json](../../symlinks/lazyvim/lazy-lock.json)
- [lazy-lock.json](../../symlinks/lazyvim/lazyvim.json)

## Awesome LazyVim

- [folke](https://github.com/folke/dot/tree/master/nvim)
- [Matt-FTW](https://github.com/Matt-FTW/dotfiles/tree/main/.config/nvim)
- [craftzdog](https://github.com/craftzdog/dotfiles-public/tree/master/.config/nvim)
- [Nv](https://github.com/appelgriebsch/Nv)
- [ian-ie](https://github.com/ian-ie/LazyVim)

## Awesome Neovim

- [Popular Neovim Configurations by Dotfyle](https://dotfyle.com/neovim/configurations/top)
- [Trending Neovim Plugins by Dotfyle](https://dotfyle.com/neovim/plugins/trending)
- [AstroCommunity](https://github.com/AstroNvim/astrocommunity)
- [Lazyman](https://github.com/doctorfree/nvim-lazyman)
- [pkazmier](https://github.com/pkazmier/nvim)
- [v1nh1shungry](https://github.com/v1nh1shungry/.dotfiles/tree/main/nvim)

## TODO

- [ ] Check out the great [:h lua-guide](https://neovim.io/doc/user/lua-guide.html#lua-guide).
- [ ] Use my own plugins in LazyExtra like Nv's [plugins/extras/](https://github.com/appelgriebsch/Nv/tree/main/lua/plugins/extras) and [lazyvim.json](https://github.com/appelgriebsch/Nv/blob/main/lazyvim.json).
- [ ] Map `gd` to both lsp_definition and lsp_references like vscode and idea, maybe give `gr` to ReplaceWithRegister.
- [ ] Can I use NvChad's theme in LazyVim?
- [ ] [extras.vscode](https://www.lazyvim.org/extras/vscode)
- [ ] [Org Mode](https://github.com/topics/orgmode-nvim) in nvim, or nvim-neorg/neorg like [stevearc](https://github.com/stevearc/dotfiles/blob/eeb506f9afd32cd8cd9f2366110c76efaae5786c/.config/nvim/lua/plugins/neorg.lua).
- [ ] Fix Java DAP timeout problem, see [nvim-jdtls](https://github.com/mfussenegger/nvim-jdtls).
- [ ] [ChatGPT.nvim](https://github.com/jackMort/ChatGPT.nvim), eg. [AstroCommunity](https://github.com/AstroNvim/astrocommunity/tree/1f3a6ec008b404c72f84093fe25c574ba63fc256/lua/astrocommunity/editing-support/chatgpt-nvim), [Matt-FTW](https://github.com/Matt-FTW/dotfiles/blob/main/.config/nvim/lua/plugins/extras/coding/ai/gpt.lua)
- [ ] [oil.nvim](https://github.com/stevearc/oil.nvim)
- [ ] [markdown.nvim](https://github.com/MeanderingProgrammer/markdown.nvim)
- [ ] [telescope-file-browser](https://github.com/nvim-telescope/telescope-file-browser.nvim), eg. [craftzdog](https://github.com/craftzdog/dotfiles-public/blob/master/.config/nvim/lua/plugins/editor.lua), [Matt-FTW](https://github.com/Matt-FTW/dotfiles/blob/main/.config/nvim/lua/plugins/extras/editor/telescope/file-browser.lua)
- [ ] Keybindings investigation:
  - DoomEmacs
  - [Kickstart](https://github.com/nvim-lua/kickstart.nvim)
  - [AstroNvim](https://github.com/AstroNvim/AstroNvim)
  - [Lazyman](https://github.com/doctorfree/nvim-lazyman)
  - [rafi](https://github.com/rafi/vim-config#custom-key-mappings)
  - [modern-neovim](https://github.com/alpha2phi/modern-neovim)
- [ ] translate

  - [JuanZoran/Trans.nvim](https://github.com/JuanZoran/Trans.nvim)
  - [voldikss/vim-translator](https://github.com/voldikss/vim-translator)
  - uga-rosa/translate.nvim

    ```lua
    {
      "uga-rosa/translate.nvim",
      event = "VeryLazy",
      config = function()
        require("translate").setup({
          default = {
            command = "translate_shell",
          },
          preset = {
            output = {
              split = {
                append = true,
              },
            },
          },
        })
      end,
    },
    ```

- [ ] Refactor patch like [overrides.lua](https://github.com/ian-ie/LazyVim/blob/master/lua/plugins/overrides.lua).
