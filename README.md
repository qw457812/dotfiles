<p align="center">
  <a href="https://git.io/typing-svg"><img src="https://readme-typing-svg.demolab.com?font=Fira+Code&duration=3500&pause=2000&color=21C8B8&center=true&vCenter=true&width=550&height=50&lines=Personal+dotfiles+on+macOS+managed+by+chezmoi" alt="dotfiles-typing-svg" /></a>
</p>

## [Goku](https://github.com/yqrashawn/GokuRakuJoudo)

Hack my keyboard via [Karabiner](https://github.com/pqrs-org/Karabiner-Elements) and maintain its [config](dot_config/karabiner.edn) with Goku.

> Head over to [nikitavoloboev](https://github.com/nikitavoloboev)'s [personal wiki](https://wiki.nikiv.dev/macOS/apps/karabiner/) to learn more about karabiner and goku.

<details>
<summary><strong>Here are some settings</strong> (outdated, click to see)</summary>

| Type              | From                         | To                                                                | Comment                                                                                                                                                                    | Favorite | Todo                         |
| ----------------- | ---------------------------- | ----------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------- | ---------------------------- |
| layer             | space+any                    | shift+any                                                         | use the most strongest finger                                                                                                                                              | yes!     |                              |
| layer             | v/m+any                      | control+any                                                       | use the second strongest finger                                                                                                                                            | yes!     |                              |
| layer             | s+h/j/k/l                    | arrow keys                                                        |                                                                                                                                                                            | yes!     |                              |
| layer             | s+d/f                        | copy/paste                                                        |                                                                                                                                                                            |          |                              |
| layer             | d+j/k                        | cmd+shift+]/cmd+shift+[ in chrome; ctrl+tab/ctrl+shift+tab in wps | switch tabs in most apps                                                                                                                                                   | yes      |                              |
| layer             | d+m                          | maximize window                                                   | remap [Rectangle](https://github.com/rxhanson/Rectangle)                                                                                                                   |          |                              |
| layer             | d+f/s                        | clicking(like vimium-f)/scrolling                                 | remap [Homerow](https://www.homerow.app/)                                                                                                                                  |          |                              |
| layer             | f+j/k                        | delete/return                                                     | so easy to delete                                                                                                                                                          | yes!     |                              |
| layer             | w+any                        | launch application                                                | w+j -> open chrome when not in chrome; w+j -> cmd+` when already in chrome                                                                                                 | yes!     |                              |
| layer             | o+any                        | open website                                                      | o+f -> create new tab of chrome                                                                                                                                            |          |                              |
| layer             | a+h/j/k/l/v/b/n              | mouse navigation/click                                            | during navigation: hold f to slow down, hold s to scroll                                                                                                                   |          | avoid pinky problem          |
| layer             | a+i/o                        | zoom in/out                                                       |                                                                                                                                                                            |          |                              |
| layer             | t+any                        | toggle setting/information                                        | t+d -> toggle dark mode                                                                                                                                                    |          |                              |
| layer             | g+h/j/k/l                    | home/page_down/page_up/end                                        |                                                                                                                                                                            |          |                              |
| layer             | x+h/j/k/l                    | shift+arrow                                                       | vi visual mode                                                                                                                                                             |          |                              |
| layer             | r+h/j/k/l                    | scrolling                                                         |                                                                                                                                                                            |          |                              |
| simultaneous keys | j+k                          | esc                                                               |                                                                                                                                                                            | yes      |                              |
| simultaneous keys | m+k                          | translate                                                         | remap [Easydict](https://github.com/tisfeng/Easydict)                                                                                                                      |          | left hand mode with mouse    |
| modifier alone    | left cmd                     | cmd+tab                                                           | so easy to switch previous app                                                                                                                                             | yes!     |                              |
| modifier alone    | right cmd                    | mouse center click to active app, then maximize window            | use it a lot when vimium/ideavim lose focus in chrome/IntelliJ                                                                                                             | yes      |                              |
| modifier alone    | left option                  | tmux prefix                                                       |                                                                                                                                                                            | yes      |                              |
| modifier alone    | right option                 | translate in chrome/IntelliJ/Others                               | remap [immersive-translate](https://immersivetranslate.com/)/[Translation](https://github.com/YiiGuxing/TranslationPlugin)/[Easydict](https://github.com/tisfeng/Easydict) | yes      |                              |
| modifier alone    | left shift                   | switch english/chinese input                                      | by Rime (nothing to do with goku)                                                                                                                                          |          | avoid pinky problem          |
| modifier alone    | right shift                  | caps_lock                                                         | turn on caps_lock to enter vi mode (in process)                                                                                                                            |          | more vi binding              |
| modifier alone    | fn                           | copy                                                              |                                                                                                                                                                            |          |                              |
| modifier alone    | left control                 | paste                                                             |                                                                                                                                                                            |          |                              |
| other             | caps_lock                    | esc(pressed alone)/control(as modifier)                           | use `j+k` and `v/m+any` instead                                                                                                                                            |          |                              |
| mouse             | right click                  | copy word(double right click)/selected(hold right click)          |                                                                                                                                                                            |          |                              |
| mouse             | option/command + left click  | copy word/selected                                                |                                                                                                                                                                            |          |                              |
| mouse             | middle click                 | paste(hold middle click to overwrite)                             |                                                                                                                                                                            |          |                              |
| trackpad          | s/d + finger on trackpad     | copy word/selected                                                |                                                                                                                                                                            |          | easy to accidentally trigger |
| trackpad          | f + finger on trackpad       | paste(hold f to overwrite)                                        |                                                                                                                                                                            |          | easy to accidentally trigger |
| trackpad          | h/j/k/l + finger on trackpad | arrow keys(one finger), home/page_down/page_up/end(two fingers)   |                                                                                                                                                                            |          | easy to accidentally trigger |

</details>

Using [Glove80](https://www.moergo.com/) keyboard.

Using [WhatPulse](https://whatpulse.org/) to track keyboard input.

TODO:

- [ ] Try [Glove80 Layout Editor](https://my.glove80.com/).
- [ ] Try [ZMK](https://zmk.dev/) or [QMK](https://docs.qmk.fm/).
  - [qmk.nvim](https://github.com/codethread/qmk.nvim)
  - [keymap-editor](https://github.com/nickcoutsos/keymap-editor)

## [Neovim](https://neovim.io/)

[My neovim config](dot_config/nvim) powered by [LazyVim](https://github.com/LazyVim/LazyVim).

TODO:

1. [x] Try [NvChad](https://github.com/NvChad/NvChad), [LazyVim](https://github.com/LazyVim/LazyVim), [Kickstart](https://github.com/nvim-lua/kickstart.nvim), [AstroNvim](https://github.com/AstroNvim/AstroNvim) by [Lazyman](https://github.com/doctorfree/nvim-lazyman).
2. [ ] Find a set of keybindings that can be used everywhere, [equivalent mapping configurations for other VIM integrations](https://github.com/magidc/nvim-config#equivalent-mapping-configurations-for-other-ides-vim-integrations):
   - IDE
     - [ ] [IdeaVim](#ideavim)
     - [ ] [VSCode Neovim](#vscode-neovimhttpsgithubcomvscode-neovimvscode-neovim)
     - [ ] [Doom Emacs](#doom-emacs)
   - File manager
     - [ ] Terminal: [Yazi](#yazihttpsgithubcomsxyaziyazi)
     - [ ] Neovim: [neo-tree.nvim](https://github.com/nvim-neo-tree/neo-tree.nvim)
     - [ ] [VSCode](#vscode-neovimhttpsgithubcomvscode-neovimvscode-neovim): Built-in Explorer view
     - [ ] [IdeaVim](#ideavim): [NERDTree](https://github.com/JetBrains/ideavim/wiki/NERDTree-support)
   - Others
     - [ ] [fish_vi_key_bindings](https://fishshell.com/docs/current/cmds/fish_vi_key_bindings.html)
     - [ ] [tmux-copy-mode](#oh-my-tmuxhttpsgithubcomgpakosztmux) or [wezterm-copy-mode](https://wezfurlong.org/wezterm/copymode.html)
     - [ ] [less](dot_config/lesskey)

Tips:

1. Remap `esc`.
   - For all keyboard (mainly for Apple Internal Keyboard): remap `jk` to `esc` by karabiner.
   - For Glove80 specifically: remap one of the **thumb keys** to `esc` by karabiner.
   - In vim(s): `inoremap jj <esc>` or `inoremap jk <esc>`.
2. Turn up `Key repeat rate` and turn down `Delay until repeat` in `System Settings` -> `Keyboard`.
   See [.macos](executable_dot_macos).
3. When leaving insert mode, auto switch IME to English (if necessary).
   - By [Rime](https://rime.im/)'s [vim_mode](https://github.com/rime/home/blob/11bbdb85d2acbb6789433064711b03b4952aa7f5/blog/source/release/squirrel/index.md?plain=1#L256) app option, see [squirrel.custom.yaml](private_Library/Rime/squirrel.custom.yaml).
   - Use [vim.g.neovide_input_ime](https://neovide.dev/configuration.html#ime) with `autocmd` in [Neovide](https://neovide.dev/).
4. Remap `shift` (optional).
   - For all keyboard: remap `space` to `shift` by karabiner.
     > The original tap and hold (repeat) functions of `space` are still available.

## [IdeaVim](https://github.com/JetBrains/ideavim)

[.ideavimrc](dot_ideavimrc)

## [VSCode Neovim](https://github.com/vscode-neovim/vscode-neovim)

[settings.json](symlinks/vscode/settings.json)

[keybindings.json](symlinks/vscode/keybindings.json)

## [Doom Emacs](https://github.com/doomemacs/doomemacs)

[DOOMDIR](dot_config/doom)

Using [Emacs Plus](https://github.com/d12frosted/homebrew-emacs-plus).

## [Fish](https://fishshell.com)

[fish config](dot_config/private_fish)

## [Oh my tmux!](https://github.com/gpakosz/.tmux)

[.tmux.conf.local](dot_tmux.conf.local)

## [Yazi](https://github.com/sxyazi/yazi)

[yazi config](dot_config/yazi)

## [RIME](https://rime.im/)

[My rime config](private_Library/Rime) for Chinese input based on [rime-ice](https://github.com/iDvel/rime-ice) and [TigerCode](https://tiger-code.com/).

Using [InputSourcePro](https://github.com/runjuu/InputSourcePro) to keep [Squirrel](https://github.com/rime/squirrel) as the only input source on macOS, instead of ABC.

And using [ShowyEdge](https://github.com/pqrs-org/ShowyEdge) to notice when input source automatically changes to ABC.

Using [emacs-rime](https://github.com/DogLooksGood/emacs-rime) in Doom Emacs and [rime-ls](https://github.com/wlh320/rime-ls) in Neovim.

## [SketchyBar](https://github.com/FelixKratz/SketchyBar)

[sketchybarrc](dot_config/sketchybar/executable_sketchybarrc)

## [yabai](https://github.com/koekeishiya/yabai)

[.yabairc](executable_dot_yabairc)

TODO:

- [ ] Try [AeroSpace](https://github.com/nikitabobko/AeroSpace).

## [zathura](https://github.com/zegervdv/homebrew-zathura)

[zathurarc](dot_config/zathura/zathurarc)

Using [zathura-pdf-poppler](https://github.com/zegervdv/homebrew-zathura#install-and-link-one-of-the-two-plugins) plugin.

Fix [zathura auto focus on open](https://github.com/zegervdv/homebrew-zathura/issues/62#issuecomment-1413968157) problem by using yabai.

## TODO

- [ ] Termux packages
  - <https://www.chezmoi.io/user-guide/advanced/install-packages-declaratively/>
  - <https://www.chezmoi.io/user-guide/use-scripts-to-perform-actions/#install-packages-with-scripts>

### Nix

#### Install

- [Determinate Nix Installer](https://github.com/DeterminateSystems/nix-installer)
- [nix-darwin](https://github.com/nix-darwin/nix-darwin)
- [home-manager](https://github.com/nix-community/home-manager)

#### Docs

- [Zero to Nix from Determinate Systems](https://zero-to-nix.com/start/install/)
- [nix.dev](https://github.com/nixos/nix.dev)

#### Dotfiles

- [johnstegeman](https://github.com/johnstegeman/dotfiles/tree/nix): chezmoi + nix (nix-darwin and home-manager)
