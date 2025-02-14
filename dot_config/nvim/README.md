# 💤 LazyVim

> A [starter template](https://github.com/LazyVim/starter) for [LazyVim](https://github.com/LazyVim/LazyVim).\
> Refer to the [documentation](https://lazyvim.github.io/installation) to get started.

Using this [commit](https://github.com/LazyVim/starter/commit/cb79b0e6a9d0ec81041150dc87fe47352a54a2ba).

## Chezmoi Symlinks

- [lazyvim.json](../../symlinks/nvim/lazyvim.json)
- [lazy-lock.json](../../symlinks/nvim/lazy-lock.json)

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
- [aaronlifton](https://github.com/aaronlifton/.config/tree/main/.config/nvim)
  > [Python](https://github.com/aaronlifton/.config/blob/main/.config/nvim/lua/plugins/extras/lang/python-extended.lua)
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
- [xzbdmw](https://github.com/xzbdmw/nvimconfig)
- [rafi](https://github.com/rafi/vim-config)
- [Saiiru](https://github.com/Saiiru/neovim)
- [huwqchn](https://github.com/huwqchn/.dotfiles/tree/main/config/nvim)
- [liubianshi](https://github.com/liubianshi/lazyvim)
  > Author of cmp-lsp-rimels.

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
- [willothy](https://github.com/willothy/nvim-config)
- [yetone](https://github.com/yetone/cosmos-nvim)
- [MasouShizuka](https://github.com/MasouShizuka/config/tree/main/neovim)
  > With Chinese comments.
- [razak17](https://github.com/razak17/nvim)

## Lazy Tips

- [`opts`, `dependencies`, `cmd`, `event`, `ft` and `keys` are always merged with the parent spec. Any other property will override the property from the parent spec.](https://lazy.folke.io/usage/structuring)
  > [If you have multiple specs for the same plugin, then all `opts` will be evaluated, but only the last `config`.](https://github.com/LazyVim/LazyVim/pull/4122#issuecomment-2241563662)

## Performance

### Holding down `j`

| Plugin                                                                                | bigtime |
| ------------------------------------------------------------------------------------- | ------- |
| [nvim-treesitter-context](https://github.com/nvim-treesitter/nvim-treesitter-context) | yes     |
| [dropbar.nvim](https://github.com/Bekaboo/dropbar.nvim)                               | no      |
| [twilight.nvim](https://github.com/folke/twilight.nvim)                               | yes     |
| [3rd/image.nvim](https://github.com/3rd/image.nvim)                                   | yes     |

## TODO

- [x] Check out the great [:h lua-guide](https://neovim.io/doc/user/lua-guide.html#lua-guide).
- [ ] Map `gd` to both lsp_definition and lsp_references like vscode and idea, maybe give `gr` to ReplaceWithRegister.

  ```lua
  {
    "folke/zen-mode.nvim",
    opts = function(_, opts)
      local on_open = opts.on_open or function() end
      opts.on_open = function()
        on_open() -- <cr> not working here: "No LSP References found", should go to definition
        -- something else
      end
    end,
  }
  ```

- [ ] Fix Java DAP timeout problem, see [nvim-jdtls](https://github.com/mfussenegger/nvim-jdtls).
  - Use [nvim-java/nvim-java](https://github.com/nvim-java/nvim-java) instead of `nvim-jdtls`.
    - Like appelgriebsch's [plugins/lang.lua](https://github.com/appelgriebsch/Nv/blob/main/lua/plugins/lang.lua) and [plugins/extras/lang/nvim-java.lua](https://github.com/appelgriebsch/Nv/blob/main/lua/plugins/extras/lang/nvim-java.lua), [contributor](https://github.com/LazyVim/LazyVim/pull/1192/commits/69a96525ebd3fcbb0128549104d3821803bb8948) of extras.lang.java.
      - Lazyvim [PR](https://github.com/LazyVim/LazyVim/pull/2211) for nvim-java.
    - Like [dragove](https://github.com/dragove/dotfiles/blob/master/nvim/.config/nvim/lua/plugins/lang/java.lua), [contributor](https://github.com/LazyVim/LazyVim/commit/61fae7d23f5689a9112b265f4bfb8468a131ae66) of extras.lang.java.
    - [Install nvim-java on Lazyvim](https://github.com/nvim-java/nvim-java/wiki/Lazyvim).
    - [nvim-java/starter-lazyvim](https://github.com/nvim-java/starter-lazyvim)
  - [ ] Check [issue 97 of lsp_signature.nvim](https://github.com/ray-x/lsp_signature.nvim/issues/97#issuecomment-1960919483).
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
- [ ] [codecompanion.nvim](https://github.com/olimorris/codecompanion.nvim)
- [ ] [ChatGPT.nvim](https://github.com/jackMort/ChatGPT.nvim), eg. [AstroCommunity](https://github.com/AstroNvim/astrocommunity/tree/1f3a6ec008b404c72f84093fe25c574ba63fc256/lua/astrocommunity/editing-support/chatgpt-nvim), [Matt-FTW](https://github.com/Matt-FTW/dotfiles/blob/main/.config/nvim/lua/plugins/extras/coding/ai/gpt.lua)
- [ ] Check this [copilot-chat-v2-fzf.lua](https://github.com/jellydn/lazy-nvim-ide/blob/main/lua/plugins/extras/copilot-chat-v2-fzf.lua).
- [x] [Markdown.nvim](https://github.com/MeanderingProgrammer/markdown.nvim) or [markview.nvim](https://github.com/OXY2DEV/markview.nvim).
  > Mentioned by this [PR](https://github.com/LazyVim/LazyVim/pull/4139).
- [x] Choose a file browser between neo-tree, oil, mini-files, [others](https://github.com/rockerBOO/awesome-neovim#file-explorer).
  - [Telescope-file-browser](https://github.com/nvim-telescope/telescope-file-browser.nvim), eg. [craftzdog](https://github.com/craftzdog/dotfiles-public/blob/master/.config/nvim/lua/plugins/editor.lua), [Matt-FTW](https://github.com/Matt-FTW/dotfiles/blob/main/.config/nvim/lua/plugins/extras/editor/telescope/file-browser.lua)
- [ ] [Toggleterm](https://github.com/akinsho/toggleterm.nvim) by this [issue](https://github.com/LazyVim/LazyVim/issues/539).
  - [toggleterm-manager.nvim](https://github.com/ryanmsnyder/toggleterm-manager.nvim)
- [ ] Keybindings investigation:
  - DoomEmacs
  - [Kickstart](https://github.com/nvim-lua/kickstart.nvim)
  - [AstroNvim](https://github.com/AstroNvim/AstroNvim)
    - [astrocore_mappings.lua](https://github.com/AstroNvim/AstroNvim/blob/main/lua/astronvim/plugins/_astrocore_mappings.lua)
    - [astrolsp_mappings.lua](https://github.com/AstroNvim/AstroNvim/blob/main/lua/astronvim/plugins/_astrolsp_mappings.lua)
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
    - [Kaiser-Yang](https://github.com/Kaiser-Yang/dotfiles/tree/main/.config/nvim), the author of [blink-cmp-dictionary](https://github.com/Kaiser-Yang/blink-cmp-dictionary).
      - [rime_ls.lua](https://github.com/Kaiser-Yang/dotfiles/blob/bdda941b06cce5c7505bc725f09dd3fa17763730/.config/nvim/lua/plugins/rime_ls.lua)
      - [blink_cmp.lua](https://github.com/Kaiser-Yang/dotfiles/blob/main/.config/nvim/lua/plugins/blink_cmp.lua)
    - [ ] [MACOS_nvim_config](https://github.com/pxwg/MACOS_nvim_config) and [LM-nvim](https://github.com/pxwg/LM-nvim) of pxwg, find from this [issue](https://github.com/Saghen/blink.cmp/issues/936).
  - [im-select.nvim](https://github.com/keaising/im-select.nvim)
- [ ] LazyVim with Chinese comment:
  - [EasonMo](https://github.com/EasonMo/myLazyVim)
  - [yunxiaoxiao11](https://github.com/yunxiaoxiao11/nvimlazy) with [.ideavimrc](https://github.com/yunxiaoxiao11/nvimlazy/blob/main/jetbrains/.ideavimrc).
  - [zooeywm](https://github.com/zooeywm/dotfiles/tree/main/LazyVim)
  - [JensenQi](https://github.com/JensenQi/nvim)
- [ ] Refactor patch like [overrides.lua](https://github.com/ian-ie/LazyVim/blob/master/lua/plugins/overrides.lua).
- [ ] Check this [keymaps.lua](https://github.com/WillEhrendreich/nvimconfig/blob/7ab5b0d0ee485d58df3cc3e1f55c6446155f29a1/lua/config/keymaps.lua).
- [ ] Matt-FTW's [vscode.lua](https://github.com/Matt-FTW/dotfiles/blob/main/.config/nvim/lua/plugins/extras/util/vscode.lua), and [search](https://github.com/search?q=repo%3AMatt-FTW%2Fdotfiles%20vscode%20%3D%20true&type=code) the `vscode = true` plugins.
  - Echasnovski's [vscode.lua](https://github.com/echasnovski/nvim/blob/master/src/vscode.lua).
- [ ] [marks](https://github.com/rafi/vim-config#plugin-marks)
- [ ] [lang/tmux](https://github.com/rafi/vim-config/blob/b9648dcdcc6674b707b963d8de902627fbc887c8/lua/rafi/plugins/extras/lang/tmux.lua)
- [ ] [vim.g.maplocalleader = ","](https://github.com/wfxr/dotfiles/blob/661bfabf3b813fd8af79d881cd28b72582d4ccca/vim/nvim/lua/config/options.lua#L6) or `,,`, `,e` keymaps.
  > [grug-far use `localleader` by default](https://github.com/MagicDuck/grug-far.nvim#%EF%B8%8F-configuration) as that is the vim [recommended](https://learnvimscriptthehardway.stevelosh.com/chapters/11.html#local-leader) way for plugins.
- [ ] [rebelot/heirline.nvim](https://github.com/rebelot/heirline.nvim) like [dragove](https://github.com/dragove/dotfiles/blob/master/nvim/.config/nvim/lua/plugins/ui/heirline.lua)
- [ ] [vim-matchup](https://github.com/andymass/vim-matchup) like [amaanq](https://github.com/amaanq/nvim-config/blob/master/lua/plugins/coding.lua)
- [ ] `venv-selector.nvim`'s [on_venv_activate_callback](https://github.com/linux-cultist/venv-selector.nvim/tree/regexp?tab=readme-ov-file#run-your-own-code-on-venv-activation-on_venv_activate_callback) like [inogai](https://github.com/inogai/neovim-config-lazy/blob/50f68f6acc0cea283a0e89bddde6f9897680c749/lua/plugins/python.lua) with `toggleterm`
- [ ] Dashboard logo like [shxfee](https://github.com/shxfee/dotfiles/blob/067e65a3bb43c0646d117a6eac16f862b03a82d6/nvim/lua/shxfee/plugins/temp.lua#L166).
- [x] [symbol-usage.nvim](https://github.com/Wansmer/symbol-usage.nvim) like [jellydn](https://github.com/jellydn/lazy-nvim-ide/blob/main/lua/plugins/lsp.lua)
- [x] [telescope-undo.nvim](https://github.com/debugloop/telescope-undo.nvim) or [undotree](https://github.com/mbbill/undotree) like [jellydn](https://github.com/jellydn/lazy-nvim-ide/blob/main/lua/plugins/undotree.lua)
- [ ] [mini.bracketed](https://github.com/echasnovski/mini.bracketed)
- [ ] [keymap-amend.nvim](https://github.com/anuvyklack/keymap-amend.nvim)
- [ ] [flatten.nvim](https://github.com/willothy/flatten.nvim) like [amaanq](https://github.com/amaanq/nvim-config/blob/master/lua/plugins/editor.lua)
- [ ] [benlubas/molten-nvim](https://github.com/benlubas/molten-nvim) for jupyter
- [ ] Alternative to markdown-preview.nvim: [toppair/peek.nvim](https://github.com/toppair/peek.nvim) like [dpetka2001](https://github.com/dpetka2001/dotfiles/blob/4ae0b9e9a67e2a37a4fee7773a8c876d1ac890f3/dot_config/nvim/lua/plugins/tools.lua#L107).
- [ ] [nvim-recorder](https://github.com/chrisgrieser/nvim-recorder)
- [x] [nvim-ufo](https://github.com/kevinhwang91/nvim-ufo)
- [ ] [rasulomaroff/reactive.nvim](https://github.com/rasulomaroff/reactive.nvim)
- [x] lang.zsh like [aimuzov](https://github.com/aimuzov/LazyVimx/blob/main/lua/lazyvimx/extras/lang/zsh.lua).
- [x] [tiny-inline-diagnostic.nvim](https://github.com/rachartier/tiny-inline-diagnostic.nvim) like [aimuzov](https://github.com/search?q=repo%3Aaimuzov%2FLazyVimx%20tiny-inline-diagnostic.nvim&type=code).
- [ ] Fix lazy loading: telescope-undo.nvim, telescope-zoxide, telescope-file-browser.nvim, smart-open.nvim
  - Check this [telescope plugin example](https://lazyvim-ambitious-devs.phillips.codes/course/chapter-19/#_complex_plugin_example_telescope_live_grep_args).
- [ ] Map `u`/`d`/`q`, and unmap `dd` for `man` filetype.
- [ ] Maybe press `]b]]][[]` instead of `]b]b]b]b[b[b]b` by [hydra.nvim](https://github.com/anuvyklack/hydra.nvim).
  - [pogyomo/submode.nvim](https://github.com/pogyomo/submode.nvim)
- [ ] `<D-s>` not working in alacritty.
- [x] Better terminal keymaps than `<leader>.`.
- [ ] Better `M`/`m<space>` keymaps.
- [x] Better `<leader>ff` keymaps since we have `<leader><space>`.
- [ ] Check [lsp_signature.nvim config of AstroNvim](https://github.com/AstroNvim/astrocommunity/blob/aaaa844e45420cd7b5f11b7c399bee919513d1d5/lua/astrocommunity/lsp/lsp-signature-nvim/init.lua).
- [x] Map `esc` for some buffers (maybe floating windows?) in [close.lua](lua/plugins/close.lua).
  - Maybe map `q` to close window like [rafi](https://github.com/rafi/vim-config/blob/814f312d92e97282913f4c3ef5f09712840b5604/lua/rafi/config/keymaps.lua#L374), and map `<C-q>` for macros.
- [ ] Check this [util/path.lua](https://github.com/sakakibara/dotfiles/blob/f281ed9865623e204becbc3b87b3983045421422/dot_config/nvim/lua/util/path.lua).
- [ ] Use `<leader>f,` instead of `<leader>fc` like [chrisgrieser](https://github.com/chrisgrieser/.config/blob/88eb71f88528f1b5a20b66fd3dfc1f7bd42b408a/nvim/lua/config/lazy.lua#L129).
- [ ] Use [olimorris/persisted.nvim](https://github.com/olimorris/persisted.nvim) instead of `folke/persistence.nvim` like [Matt-FTW](https://github.com/Matt-FTW/dotfiles/blob/ccaa72f977f207cc63ee9798003021534d3053c6/.config/nvim/lua/plugins/extras/util/persisted.lua#L3).
  - Or [stevearc/resession.nvim](https://github.com/stevearc/resession.nvim) mentioned in [astrocore](https://github.com/AstroNvim/astrocore#-installation).
- [ ] Highlight trailing whitespace and inline double space.
- [ ] Check this PR [feat(format): format mode (file | hunks)](https://github.com/LazyVim/LazyVim/pull/4801/files).
- [x] More keymaps for lazy like [chrisgrieser](https://github.com/chrisgrieser/.config/blob/main/nvim/lua/config/lazy.lua).
- [ ] Try [colortils.nvim](https://github.com/max397574/colortils.nvim).
- [ ] Try [cmdbuf.nvim](https://github.com/notomo/cmdbuf.nvim).
- [ ] Try [grapple.nvim](https://github.com/cbochs/grapple.nvim).
- [ ] Try [neominimap.nvim](https://github.com/Isrothy/neominimap.nvim).
- [ ] Try [chrisgrieser/nvim-scissors](https://github.com/chrisgrieser/nvim-scissors).
- [ ] Try [chrisgrieser/nvim-lsp-endhints](https://github.com/chrisgrieser/nvim-lsp-endhints), not working with `nvim-jdtls`.
- [ ] Try [nvzone/timerly](https://github.com/nvzone/timerly).
- [ ] Check this [Telescope.lua](https://github.com/xzbdmw/nvimlazy/blob/e4c7da89a726a5b048574e014b5ea2b1aeda67f9/lua/plugins/Telescope.lua).
- [ ] Replace `vim.endswith` and `vim.startswith` with `string.match` since I found [this commit of oil.nvim](https://github.com/stevearc/oil.nvim/commit/4de3025).
- [ ] Try [nvim-focus/focus.nvim](https://github.com/nvim-focus/focus.nvim).
- [ ] Try [jake-stewart/multicursor.nvim](https://github.com/jake-stewart/multicursor.nvim).
  > Mentioned in this [issue](https://github.com/Saghen/blink.cmp/issues/182#issuecomment-2651686405) of `blink.cmp`.
- [ ] [firenvim](https://github.com/glacambre/firenvim) like [megalithic](https://github.com/megalithic/dotfiles/blob/main/config/nvim/lua/plugins/extended/firenvim.lua).
- [ ] Check this [chezmoi.lua.tmpl](https://github.com/Nitestack/dotfiles/blob/506b895c45b8ed012a2cb0c35fe62058d8b6dbc4/config/private_dot_config/exact_nvim/lua/exact_plugins/chezmoi.lua.tmpl).
- [ ] Check this [LspProgress autocmds](https://github.com/folke/snacks.nvim/blob/main/docs/notifier.md#-examples).
- [ ] Check [damoye](https://github.com/damoye/nvim/tree/lazyvim).
- [ ] [j/k navigation](https://github.com/ibhagwan/fzf-lua/issues/501#issuecomment-1219594641) for fzf-lua.
- [x] Map `<M-i>` to `<C-i>` in nvim, and map `<C-i>` to `<M-i>` in terminal.
  - Like mrbeardad: [nvim](https://github.com/mrbeardad/nvim/blob/master/lua%2Fuser%2Fconfigs%2Fkeymaps.lua#L69) and [terminal](https://github.com/mrbeardad/MyIDE/blob/0792378a80e3eb72ce47de8e78d9df6c37002bbf/wt/settings.json#L425).
- [ ] Create a `state` util to cache the state (like [zen-mode.nvim](https://github.com/folke/zen-mode.nvim/blob/29b292bdc58b76a6c8f294c961a8bf92c5a6ebd6/lua/zen-mode/plugins.lua#L137)) instead of using `vim.g.user_...`
  - [vim.g.user_zenmode_on](lua/plugins/ui.lua), [vim.g.user_minianimate_disable_old](lua/plugins/ui.lua)
  - [local neovide_state = {}](lua/config/keymaps.lua)
- [ ] Preview scroll up/down: `<C-u>`/`<C-d>` or `<C-f>`/`<C-b>`?
  - `<C-f>`/`<C-b>`: fzf, telescope, lsp-hover-doc, blink-cmp-doc, which-key-popup, yazi, nvim-ufo, trans.nvim
    - `<C-b>` used for tmux prefix.
  - `<C-u>`/`<C-d>`: lazygit
    - `i_CTRL-U` used for unix-line-discard in fzf.
    - `<C-u>` used for list_scroll_up.
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
