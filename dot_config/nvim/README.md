# 💤 LazyVim

> A [starter template](https://github.com/LazyVim/starter) for [LazyVim](https://github.com/LazyVim/LazyVim).\
> Refer to the [documentation](https://lazyvim.github.io/installation) to get started.

Using this [commit](https://github.com/LazyVim/starter/commit/cb79b0e6a9d0ec81041150dc87fe47352a54a2ba).

## Chezmoi Symlinks

- [lazyvim.json](../../symlinks/lazyvim/lazy-lock.json)
- [lazy-lock.json](../../symlinks/lazyvim/lazyvim.json)

## Awesome LazyVim

- [folke](https://github.com/folke/dot/tree/master/nvim)
  > Author of LazyVim.
- [Popular Neovim Configurations using LazyVim by Dotfyle](https://dotfyle.com/neovim/configurations/top?plugins=LazyVim/LazyVim)
- [craftzdog](https://github.com/craftzdog/dotfiles-public/tree/master/.config/nvim)
- [Nv](https://github.com/appelgriebsch/Nv)
  > Contributor of extras.lang.java.
- [aimuzov](https://github.com/aimuzov/LazyVimx)
  > Find from this [issue](https://github.com/LazyVim/LazyVim/pull/3503#issuecomment-2177573748), UI looks good.
  - [lazyvim.json](https://github.com/aimuzov/dotfiles/blob/main/dot_config/nvim/lazyvim.json)
- [jacquin236](https://github.com/jacquin236/minimal-nvim)
- [moetayuko](https://github.com/moetayuko/nvimrc)
  > [Contributor](https://github.com/aserowy/tmux.nvim/pull/123) of `aserowy/tmux.nvim`.
- [Matt-FTW](https://github.com/Matt-FTW/dotfiles/tree/main/.config/nvim)
- [amaanq](https://github.com/amaanq/nvim-config)
- [ian-ie](https://github.com/ian-ie/LazyVim)
- [TobinPalmer](https://github.com/TobinPalmer/dots/tree/main/nvim)
- [wfxr](https://github.com/wfxr/dotfiles/tree/master/vim/nvim)
- [jellydn](https://github.com/jellydn/lazy-nvim-ide)
- [eslam-allam](https://github.com/eslam-allam/nvim-lazy)
  > Java

## Awesome Neovim

- [Popular Neovim Configurations by Dotfyle](https://dotfyle.com/neovim/configurations/top)
- [Trending Neovim Plugins by Dotfyle](https://dotfyle.com/neovim/plugins/trending)
- [Popular Preconfigured plugins by Dotfyle](https://dotfyle.com/neovim/plugins/top?categories=preconfigured)
- [Trending Preconfigured plugins by Dotfyle](https://dotfyle.com/neovim/plugins/trending?categories=preconfigured)
- [nvimdots](https://dotfyle.com/plugins/ayamir/nvimdots)
- [AstroCommunity](https://github.com/AstroNvim/astrocommunity)
- [echasnovski](https://github.com/echasnovski/nvim)
  > Author of [mini.nvim](https://github.com/echasnovski/mini.nvim).
  - [mini.basics](https://github.com/echasnovski/mini.nvim/blob/main/lua/mini/basics.lua): [Common configuration presets](https://github.com/echasnovski/mini.nvim#modules)
- [Lazyman](https://github.com/doctorfree/nvim-lazyman)
- [pkazmier](https://github.com/pkazmier/nvim)
- [v1nh1shungry](https://github.com/v1nh1shungry/.dotfiles/tree/main/nvim)
- [chrisgrieser](https://github.com/chrisgrieser/.config/tree/main/nvim)
- [sxyazi](https://github.com/sxyazi/dotfiles/tree/main/nvim)

## Lazy Tips

- [If you have multiple specs for the same plugin, then all `opts` will be evaluated, but only the last `config`](https://github.com/LazyVim/LazyVim/pull/4122#issuecomment-2241563662).

## Performance

### Holding down `j`

| Plugin                                                                                | bigtime |
| ------------------------------------------------------------------------------------- | ------- |
| [nvim-treesitter-context](https://github.com/nvim-treesitter/nvim-treesitter-context) | yes     |
| [dropbar.nvim](https://github.com/Bekaboo/dropbar.nvim)                               | no      |
| [twilight.nvim](https://github.com/folke/twilight.nvim)                               | yes     |

## TODO

- [x] Check out the great [:h lua-guide](https://neovim.io/doc/user/lua-guide.html#lua-guide).
- [ ] Map `gd` to both lsp_definition and lsp_references like vscode and idea, maybe give `gr` to ReplaceWithRegister.
- [ ] Fix Java DAP timeout problem, see [nvim-jdtls](https://github.com/mfussenegger/nvim-jdtls).
  - Use [nvim-java/nvim-java](https://github.com/nvim-java/nvim-java) instead of `nvim-jdtls`.
    - Like appelgriebsch's [plugins/lang.lua](https://github.com/appelgriebsch/Nv/blob/main/lua/plugins/lang.lua) and [plugins/extras/lang/nvim-java.lua](https://github.com/appelgriebsch/Nv/blob/main/lua/plugins/extras/lang/nvim-java.lua), [contributor](https://github.com/LazyVim/LazyVim/pull/1192/commits/69a96525ebd3fcbb0128549104d3821803bb8948) of extras.lang.java.
      - Lazyvim [PR](https://github.com/LazyVim/LazyVim/pull/2211) for nvim-java.
    - Like [dragove](https://github.com/dragove/dotfiles/blob/master/nvim/.config/nvim/lua/plugins/lang/java.lua), [contributor](https://github.com/LazyVim/LazyVim/commit/61fae7d23f5689a9112b265f4bfb8468a131ae66) of extras.lang.java.
    - [Install nvim-java on Lazyvim](https://github.com/nvim-java/nvim-java/wiki/Lazyvim).
- [ ] Python LSP improvements:
  - Fredrikaverpil's [lang/python.lua](https://github.com/fredrikaverpil/dotfiles/blob/main/nvim-fredrik/lua/lang/python.lua), [contributor](https://github.com/LazyVim/LazyVim/commits?author=fredrikaverpil) of LazyVim.
  - [moetayuko](https://github.com/moetayuko/nvimrc), Lazyvim [PR](https://github.com/LazyVim/LazyVim/pull/4141) for extras.lang.python.
    - [overseer/template/user/python.lua](https://github.com/moetayuko/nvimrc/blob/master/lua/overseer/template/user/python.lua)
- [x] Use my own plugins in LazyExtra like Nv's [plugins/extras/](https://github.com/appelgriebsch/Nv/tree/main/lua/plugins/extras) and [lazyvim.json](https://github.com/appelgriebsch/Nv/blob/main/lazyvim.json).
- [ ] `;`/`,` and `f`/`F`/`t`/`T`
  - [flash.nvim](https://github.com/folke/flash.nvim): clever-f style, get rid of `;`/`,`.
  - [demicolon.nvim](https://github.com/mawkler/demicolon.nvim): repeat diagnostic jumps (`]d`/`[d`) and nvim-treesitter-textobjects jumps (`]f`/`[f`) with `;`/`,`.
  - [eyeliner.nvim](https://github.com/jinh0/eyeliner.nvim): enhance `f`/`F`/`t`/`T`, like quick-scope.
- [ ] [Org Mode](https://github.com/topics/orgmode-nvim) in nvim, or neorg like [stevearc](https://github.com/stevearc/dotfiles/blob/eeb506f9afd32cd8cd9f2366110c76efaae5786c/.config/nvim/lua/plugins/neorg.lua).
- [ ] [ChatGPT.nvim](https://github.com/jackMort/ChatGPT.nvim), eg. [AstroCommunity](https://github.com/AstroNvim/astrocommunity/tree/1f3a6ec008b404c72f84093fe25c574ba63fc256/lua/astrocommunity/editing-support/chatgpt-nvim), [Matt-FTW](https://github.com/Matt-FTW/dotfiles/blob/main/.config/nvim/lua/plugins/extras/coding/ai/gpt.lua)
- [ ] Check this [copilot-chat-v2-fzf.lua](https://github.com/jellydn/lazy-nvim-ide/blob/main/lua/plugins/extras/copilot-chat-v2-fzf.lua).
- [ ] [Markdown.nvim](https://github.com/MeanderingProgrammer/markdown.nvim) or [markview.nvim](https://github.com/OXY2DEV/markview.nvim).
  > Mentioned by this [PR](https://github.com/LazyVim/LazyVim/pull/4139).
- [ ] Choose a file browser between neo-tree, oil, mini-files, [others](https://github.com/rockerBOO/awesome-neovim#file-explorer).
  - [Telescope-file-browser](https://github.com/nvim-telescope/telescope-file-browser.nvim), eg. [craftzdog](https://github.com/craftzdog/dotfiles-public/blob/master/.config/nvim/lua/plugins/editor.lua), [Matt-FTW](https://github.com/Matt-FTW/dotfiles/blob/main/.config/nvim/lua/plugins/extras/editor/telescope/file-browser.lua)
  - Fix chezmoi not auto apply if file opened from mini-files.
- [ ] Terminal: fix zsh-vi-mode's cursor shape.
- [ ] [Toggleterm](https://github.com/akinsho/toggleterm.nvim) by this [issue](https://github.com/LazyVim/LazyVim/issues/539).
  - [toggleterm-manager.nvim](https://github.com/ryanmsnyder/toggleterm-manager.nvim)
- [ ] Keybindings investigation:
  - DoomEmacs
  - [Kickstart](https://github.com/nvim-lua/kickstart.nvim)
  - [AstroNvim](https://github.com/AstroNvim/AstroNvim)
  - [Lazyman](https://github.com/doctorfree/nvim-lazyman)
  - [rafi](https://github.com/rafi/vim-config#custom-key-mappings)
  - [modern-neovim](https://github.com/alpha2phi/modern-neovim)
  - [nvimdots](https://github.com/ayamir/nvimdots)
  - echasnovski's [mappings-leader.lua](https://github.com/echasnovski/nvim/blob/master/src/mappings-leader.lua)
- [ ] translate
  - [JuanZoran/Trans.nvim](https://github.com/JuanZoran/Trans.nvim)
  - [voldikss/vim-translator](https://github.com/voldikss/vim-translator)
  - [uga-rosa/translate.nvim](https://github.com/uga-rosa/translate.nvim)
  - [lewis6991/hover.nvim](https://github.com/wfxr/dotfiles/blob/661bfabf3b813fd8af79d881cd28b72582d4ccca/vim/nvim/lua/plugins/lsp.lua#L29)
- [ ] Chinese input
  - [h-hg/fcitx.nvim](https://github.com/h-hg/fcitx.nvim) like [moetayuko](https://github.com/moetayuko/nvimrc/blob/ae242cc18559cd386c36feb9f999b1a9596c7d09/lua/plugins/editor.lua#L173)
  - [wlh320/rime-ls](https://github.com/wlh320/rime-ls/blob/master/doc/nvim.md)
    - [liubianshi/cmp-lsp-rimels](https://github.com/liubianshi/cmp-lsp-rimels)
  - [im-select.nvim](https://github.com/keaising/im-select.nvim)
- [ ] LazyVim with Chinese comment:
  - [EasonMo](https://github.com/EasonMo/myLazyVim)
  - [yunxiaoxiao11](https://github.com/yunxiaoxiao11/nvimlazy) with [.ideavimrc](https://github.com/yunxiaoxiao11/nvimlazy/blob/main/jetbrains/.ideavimrc).
- [ ] Refactor patch like [overrides.lua](https://github.com/ian-ie/LazyVim/blob/master/lua/plugins/overrides.lua).
- [ ] Check this [keymaps.lua](https://github.com/WillEhrendreich/nvimconfig/blob/7ab5b0d0ee485d58df3cc3e1f55c6446155f29a1/lua/config/keymaps.lua).
- [ ] Matt-FTW's [vscode.lua](https://github.com/Matt-FTW/dotfiles/blob/main/.config/nvim/lua/plugins/extras/util/vscode.lua), and [search](https://github.com/search?q=repo%3AMatt-FTW%2Fdotfiles%20vscode%20%3D%20true&type=code) the `vscode = true` plugins.
  - Echasnovski's [vscode.lua](https://github.com/echasnovski/nvim/blob/master/src/vscode.lua).
- [ ] Remove extras: coding.luasnip. (and editor.mini-files?)
- [ ] [marks](https://github.com/rafi/vim-config#plugin-marks)
- [ ] Try [smart-splits.nvim](https://github.com/mrjones2014/smart-splits.nvim) instead of tmux.nvim.
- [ ] [lang/tmux](https://github.com/rafi/vim-config/blob/b9648dcdcc6674b707b963d8de902627fbc887c8/lua/rafi/plugins/extras/lang/tmux.lua)
- [ ] [vim.g.maplocalleader = ","](https://github.com/wfxr/dotfiles/blob/661bfabf3b813fd8af79d881cd28b72582d4ccca/vim/nvim/lua/config/options.lua#L6) or `,,`, `,e` keymaps.
  > [grug-far use `localleader` by default](https://github.com/MagicDuck/grug-far.nvim#%EF%B8%8F-configuration) as that is the vim [recommended](https://learnvimscriptthehardway.stevelosh.com/chapters/11.html#local-leader) way for plugins.
- [ ] [rebelot/heirline.nvim](https://github.com/rebelot/heirline.nvim) like [dragove](https://github.com/dragove/dotfiles/blob/master/nvim/.config/nvim/lua/plugins/ui/heirline.lua)
- [ ] [vim-matchup](https://github.com/andymass/vim-matchup) like [amaanq](https://github.com/amaanq/nvim-config/blob/master/lua/plugins/coding.lua)
- [ ] `venv-selector.nvim`'s [on_venv_activate_callback](https://github.com/linux-cultist/venv-selector.nvim/tree/regexp?tab=readme-ov-file#run-your-own-code-on-venv-activation-on_venv_activate_callback) like [inogai](https://github.com/inogai/neovim-config-lazy/blob/50f68f6acc0cea283a0e89bddde6f9897680c749/lua/plugins/python.lua) with `toggleterm`
- [ ] Dashboard logo like [shxfee](https://github.com/shxfee/dotfiles/blob/067e65a3bb43c0646d117a6eac16f862b03a82d6/nvim/lua/shxfee/plugins/temp.lua#L166).
- [ ] [symbol-usage.nvim](https://github.com/Wansmer/symbol-usage.nvim) like [jellydn](https://github.com/jellydn/lazy-nvim-ide/blob/main/lua/plugins/lsp.lua)
- [ ] [telescope-undo.nvim](https://github.com/debugloop/telescope-undo.nvim) or [undotree](https://github.com/mbbill/undotree) like [jellydn](https://github.com/jellydn/lazy-nvim-ide/blob/main/lua/plugins/undotree.lua)
- [ ] [mini.bracketed](https://github.com/echasnovski/mini.bracketed)
- [ ] [flatten.nvim](https://github.com/willothy/flatten.nvim) like [amaanq](https://github.com/amaanq/nvim-config/blob/master/lua/plugins/editor.lua)
- [ ] [benlubas/molten-nvim](https://github.com/benlubas/molten-nvim) for jupyter
- [ ] [nvim-recorder](https://github.com/chrisgrieser/nvim-recorder)
- [ ] lang.zsh like [aimuzov](https://github.com/aimuzov/LazyVimx/blob/main/lua/lazyvimx/extras/lang/zsh.lua).
- [ ] Create a `state` util to cache the state (like [zen-mode.nvim](https://github.com/folke/zen-mode.nvim/blob/29b292bdc58b76a6c8f294c961a8bf92c5a6ebd6/lua/zen-mode/plugins.lua#L137)) instead of using `vim.g.user_...`
  - [vim.g.user_zenmode_on](lua/plugins/ui.lua), [vim.g.user_minianimate_disable_old](lua/plugins/ui.lua)
  - [local neovide_state = {}](lua/config/keymaps.lua)
- [ ] `which-key v3` problem with `mini.surround`/`mini.operators`/Helix-style mappings(map `mm` to `%`):

  1. problem
     - Timeout is too short, e.g. time window between `c` and `r` for `cr`.
       - Benefit: I can use `m` marks by typing `mm` slowly now.
     - No popup in normal mode anymore, e.g. `cr`/`ms`.
  2. solution

     - Increase `vim.opt.timeoutlen` from 300 to 500.
     - Use `triggers` opt of which-key:

       ```lua
       {
         "folke/which-key.nvim",
         opts = {
           triggers = {
             { "<auto>", mode = "nxsot" }, -- this line is necessary
             -- https://github.com/echasnovski/mini.nvim/issues/1058
             -- https://github.com/folke/which-key.nvim/issues/672#issuecomment-2235978897
             -- 1. Get rid of the `vim.opt.timeoutlen` limit, since `cr` is a little hard to type.
             -- 2. Fix `cR` for `cr$`, or `cR`.
             -- 3. TODO Causing Remote Flash broken on `c<space>`.
             { "c", mode = "n" },
             -- { "m", mode = { "n", "v" } },
           },
         },
       },
       ```
