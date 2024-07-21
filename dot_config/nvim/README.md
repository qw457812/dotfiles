# 💤 LazyVim

> A [starter template](https://github.com/LazyVim/starter) for [LazyVim](https://github.com/LazyVim/LazyVim).\
> Refer to the [documentation](https://lazyvim.github.io/installation) to get started.

Using this [commit](https://github.com/LazyVim/starter/commit/cb79b0e6a9d0ec81041150dc87fe47352a54a2ba).

## Chezmoi Symlinks

- [lazyvim.json](../../symlinks/lazyvim/lazy-lock.json)
- [lazy-lock.json](../../symlinks/lazyvim/lazyvim.json)

## Awesome LazyVim

- [Popular Neovim Configurations using LazyVim by Dotfyle](https://dotfyle.com/neovim/configurations/top?plugins=LazyVim/LazyVim)
- [folke](https://github.com/folke/dot/tree/master/nvim)
  > Author of LazyVim.
- [craftzdog](https://github.com/craftzdog/dotfiles-public/tree/master/.config/nvim)
- [Nv](https://github.com/appelgriebsch/Nv)
  > Contributor of extras.lang.java.
- [Matt-FTW](https://github.com/Matt-FTW/dotfiles/tree/main/.config/nvim)
- [amaanq](https://github.com/amaanq/nvim-config)
- [ian-ie](https://github.com/ian-ie/LazyVim)
- [TobinPalmer](https://github.com/TobinPalmer/dots/tree/main/nvim)
- [wfxr](https://github.com/wfxr/dotfiles/tree/master/vim/nvim)
- [jellydn](https://github.com/jellydn/lazy-nvim-ide)

## Awesome Neovim

- [Popular Neovim Configurations by Dotfyle](https://dotfyle.com/neovim/configurations/top)
- [Trending Neovim Plugins by Dotfyle](https://dotfyle.com/neovim/plugins/trending)
- [Popular Preconfigured plugins by Dotfyle](https://dotfyle.com/neovim/plugins/top?categories=preconfigured)
- [Trending Preconfigured plugins by Dotfyle](https://dotfyle.com/neovim/plugins/trending?categories=preconfigured)
- [nvimdots](https://dotfyle.com/plugins/ayamir/nvimdots)
- [AstroCommunity](https://github.com/AstroNvim/astrocommunity)
- [Lazyman](https://github.com/doctorfree/nvim-lazyman)
- [pkazmier](https://github.com/pkazmier/nvim)
- [v1nh1shungry](https://github.com/v1nh1shungry/.dotfiles/tree/main/nvim)

## TODO

- [ ] Check out the great [:h lua-guide](https://neovim.io/doc/user/lua-guide.html#lua-guide).
- [ ] Map `gd` to both lsp_definition and lsp_references like vscode and idea, maybe give `gr` to ReplaceWithRegister.
- [ ] Fix Java DAP timeout problem, see [nvim-jdtls](https://github.com/mfussenegger/nvim-jdtls).
  - Use [nvim-java/nvim-java](https://github.com/nvim-java/nvim-java) instead of `nvim-jdtls`.
    - Like appelgriebsch's [plugins/lang.lua](https://github.com/appelgriebsch/Nv/blob/main/lua/plugins/lang.lua) and [plugins/extras/lang/nvim-java.lua](https://github.com/appelgriebsch/Nv/blob/main/lua/plugins/extras/lang/nvim-java.lua), [contributor](https://github.com/LazyVim/LazyVim/pull/1192/commits/69a96525ebd3fcbb0128549104d3821803bb8948) of extras.lang.java.
      - Lazyvim [PR](https://github.com/LazyVim/LazyVim/pull/2211) for nvim-java.
    - Like [dragove](https://github.com/dragove/dotfiles/blob/master/nvim/.config/nvim/lua/plugins/lang/java.lua), [contributor](https://github.com/LazyVim/LazyVim/commit/61fae7d23f5689a9112b265f4bfb8468a131ae66) of extras.lang.java.
    - [Install nvim-java on Lazyvim](https://github.com/nvim-java/nvim-java/wiki/Lazyvim).
- [ ] Python LSP improvements:
  - Fredrikaverpil's [lang/python.lua](https://github.com/fredrikaverpil/dotfiles/blob/main/nvim-fredrik/lua/lang/python.lua), [contributor](https://github.com/LazyVim/LazyVim/commits?author=fredrikaverpil) of LazyVim.
- [ ] Use my own plugins in LazyExtra like Nv's [plugins/extras/](https://github.com/appelgriebsch/Nv/tree/main/lua/plugins/extras) and [lazyvim.json](https://github.com/appelgriebsch/Nv/blob/main/lazyvim.json).
- [ ] [Org Mode](https://github.com/topics/orgmode-nvim) in nvim, or neorg like [stevearc](https://github.com/stevearc/dotfiles/blob/eeb506f9afd32cd8cd9f2366110c76efaae5786c/.config/nvim/lua/plugins/neorg.lua).
- [ ] [ChatGPT.nvim](https://github.com/jackMort/ChatGPT.nvim), eg. [AstroCommunity](https://github.com/AstroNvim/astrocommunity/tree/1f3a6ec008b404c72f84093fe25c574ba63fc256/lua/astrocommunity/editing-support/chatgpt-nvim), [Matt-FTW](https://github.com/Matt-FTW/dotfiles/blob/main/.config/nvim/lua/plugins/extras/coding/ai/gpt.lua)
- [ ] [Markdown.nvim](https://github.com/MeanderingProgrammer/markdown.nvim) or [markview.nvim](https://github.com/OXY2DEV/markview.nvim).
- [ ] [Telescope-file-browser](https://github.com/nvim-telescope/telescope-file-browser.nvim), eg. [craftzdog](https://github.com/craftzdog/dotfiles-public/blob/master/.config/nvim/lua/plugins/editor.lua), [Matt-FTW](https://github.com/Matt-FTW/dotfiles/blob/main/.config/nvim/lua/plugins/extras/editor/telescope/file-browser.lua)
- [ ] Choose a file browser between neo-tree, oil, mini-files, [others](https://github.com/rockerBOO/awesome-neovim#file-explorer).
- [ ] Fix chezmoi not auto apply if file opened from mini-files.
- [ ] Terminal: fix zsh-vi-mode's cursor shape.
- [ ] [Toggleterm](https://github.com/akinsho/toggleterm.nvim) by this [issue](https://github.com/LazyVim/LazyVim/issues/539).
- [ ] Keybindings investigation:
  - DoomEmacs
  - [Kickstart](https://github.com/nvim-lua/kickstart.nvim)
  - [AstroNvim](https://github.com/AstroNvim/AstroNvim)
  - [Lazyman](https://github.com/doctorfree/nvim-lazyman)
  - [rafi](https://github.com/rafi/vim-config#custom-key-mappings)
  - [modern-neovim](https://github.com/alpha2phi/modern-neovim)
  - [nvimdots](https://github.com/ayamir/nvimdots)
- [ ] translate
  - [JuanZoran/Trans.nvim](https://github.com/JuanZoran/Trans.nvim)
  - [voldikss/vim-translator](https://github.com/voldikss/vim-translator)
  - [uga-rosa/translate.nvim](https://github.com/uga-rosa/translate.nvim)
  - [lewis6991/hover.nvim](https://github.com/wfxr/dotfiles/blob/661bfabf3b813fd8af79d881cd28b72582d4ccca/vim/nvim/lua/plugins/lsp.lua#L29)
- [ ] Refactor patch like [overrides.lua](https://github.com/ian-ie/LazyVim/blob/master/lua/plugins/overrides.lua).
- [ ] Check this [keymaps.lua](https://github.com/WillEhrendreich/nvimconfig/blob/7ab5b0d0ee485d58df3cc3e1f55c6446155f29a1/lua/config/keymaps.lua).
- [ ] Matt-FTW's [vscode.lua](https://github.com/Matt-FTW/dotfiles/blob/main/.config/nvim/lua/plugins/extras/util/vscode.lua), and [search](https://github.com/search?q=repo%3AMatt-FTW%2Fdotfiles%20vscode%20%3D%20true&type=code) the `vscode = true` plugins.
  - Echasnovski's [vscode.lua](https://github.com/echasnovski/nvim/blob/master/src/vscode.lua).
- [ ] Remove extras: coding.luasnip, editor.illuminate. (and editor.mini-files?)
  > [Document highlights now use native lsp functionality by default](https://www.lazyvim.org/news).
- [ ] [marks](https://github.com/rafi/vim-config#plugin-marks)
- [ ] Try [smart-splits.nvim](https://github.com/mrjones2014/smart-splits.nvim) instead of tmux.nvim.
- [ ] [lang/tmux](https://github.com/rafi/vim-config/blob/b9648dcdcc6674b707b963d8de902627fbc887c8/lua/rafi/plugins/extras/lang/tmux.lua)
- [ ] [vim.g.maplocalleader = ","](https://github.com/wfxr/dotfiles/blob/661bfabf3b813fd8af79d881cd28b72582d4ccca/vim/nvim/lua/config/options.lua#L6) or `,,`, `,e` keymaps.
- [ ] [rebelot/heirline.nvim](https://github.com/rebelot/heirline.nvim) like [dragove](https://github.com/dragove/dotfiles/blob/master/nvim/.config/nvim/lua/plugins/ui/heirline.lua)
- [ ] [vim-matchup](https://github.com/andymass/vim-matchup) like [amaanq](https://github.com/amaanq/nvim-config/blob/master/lua/plugins/coding.lua)
- [ ] `venv-selector.nvim`'s [on_venv_activate_callback](https://github.com/linux-cultist/venv-selector.nvim/tree/regexp?tab=readme-ov-file#run-your-own-code-on-venv-activation-on_venv_activate_callback) like [inogai](https://github.com/inogai/neovim-config-lazy/blob/50f68f6acc0cea283a0e89bddde6f9897680c749/lua/plugins/python.lua) with `toggleterm`
- [ ] Dashboard logo like [shxfee](https://github.com/shxfee/dotfiles/blob/067e65a3bb43c0646d117a6eac16f862b03a82d6/nvim/lua/shxfee/plugins/temp.lua#L166).
- [ ] [symbol-usage.nvim](https://github.com/Wansmer/symbol-usage.nvim) like [jellydn](https://github.com/jellydn/lazy-nvim-ide/blob/main/lua/plugins/lsp.lua)
- [ ] [undotree](https://github.com/mbbill/undotree) like [jellydn](https://github.com/jellydn/lazy-nvim-ide/blob/main/lua/plugins/undotree.lua)
  - [telescope-undo.nvim](https://github.com/debugloop/telescope-undo.nvim) like [Nv](https://github.com/appelgriebsch/Nv/blob/56b0ff93056d031666049c9a0d0b5f7b5c36b958/lua/plugins/extras/editor/undo-mode.lua) and [Matt-FTW](https://github.com/Matt-FTW/dotfiles/blob/9c7bd1b3737e3ced5bd97e6df803eaecb7692451/.config/nvim/lua/plugins/extras/editor/telescope/undotree.lua)
- [ ] Check this [copilot-chat-v2-fzf.lua](https://github.com/jellydn/lazy-nvim-ide/blob/main/lua/plugins/extras/copilot-chat-v2-fzf.lua).
- [ ] Bind `<leader>ua` to toggle `mini.animate`.
- [ ] [mini.bracketed](https://github.com/echasnovski/mini.bracketed)
- [ ] [flatten.nvim](https://github.com/willothy/flatten.nvim) like [amaanq](https://github.com/amaanq/nvim-config/blob/master/lua/plugins/editor.lua)
- [ ] `which-key v3` problem with `mini.surround`/`mini.operators`/Helix-style mappings(map `mm` to `%`):
  - Timeout is too short, e.g. time window between `c` and `r` for `cr`.
    - Benefit: I can use `m` marks by typing `mm` slowly now.
  - No popup in normal mode anymore, e.g. `cr`/`ms`.
  - How to map `Operator to EoL` for `mini.operators`? `vim.keymap.set("n", "cR", "cr$", { desc = "Replace to EoL", remap = true })` doesn't work.
- [ ] [benlubas/molten-nvim](https://github.com/benlubas/molten-nvim) for jupyter
- [ ] [grug-far.nvim](https://github.com/MagicDuck/grug-far.nvim)
  > [b1a4740](https://github.com/LazyVim/LazyVim/commit/b1a4740) feat(edgy): added support for grug-far.nvim
