<p align="center">
  <a href="https://git.io/typing-svg"><img src="https://readme-typing-svg.demolab.com/?lines=Personal+dotfiles+on+macOS+managed+by+chezmoi&font=Fira%20Code&center=true&width=550&height=50"/></a>
</p>

## [Goku](https://github.com/yqrashawn/GokuRakuJoudo)

Hack keyboard use [Karabiner](https://github.com/pqrs-org/Karabiner-Elements), and maintain ***[my karabiner config](./dot_config/karabiner.edn)*** with Goku.

Head over to [nikitavoloboev](https://github.com/nikitavoloboev)'s ***[personal wiki](https://wiki.nikiv.dev/macOS/apps/karabiner/)*** to learn more about karabiner and goku.

Tracking keyboard input use [WhatPulse](https://whatpulse.org/) to observe.

<details>
<summary><strong>Here are some settings</strong> (click to see)</summary>

| Type              | From                         | To                                                                | Comment                                                                    | Favorite | Todo                                       |
|-------------------|------------------------------|-------------------------------------------------------------------|----------------------------------------------------------------------------|----------|--------------------------------------------|
| layer             | space+any                    | shift+any                                                         | use the most strongest finger                                              | yes!     |                                            |
| layer             | v/m+any                      | control+any                                                       | use the second strongest finger                                            | yes!     |                                            |
| layer             | s+h/j/k/l                    | arrow keys                                                        |                                                                            | yes!     |                                            |
| layer             | s+d/f                        | copy/paste                                                        |                                                                            |          |                                            |
| layer             | d+j/k                        | cmd+shift+]/cmd+shift+[ in chrome; ctrl+tab/ctrl+shift+tab in wps | switch tabs in most apps                                                   | yes      |                                            |
| layer             | d+m                          | maximiz window                                                    | remap Rectangle.app                                                        |          |                                            |
| layer             | d+f/s                        | clicking(like vimium-f)/scrolling                                 | remap Homerow.app                                                          |          |                                            |
| layer             | f+j/k                        | delete/return                                                     | so easy to delete                                                          | yes!     |                                            |
| layer             | w+any                        | launch application                                                | w+j -> open chrome when not in chrome; w+j -> cmd+` when already in chrome | yes!     |                                            |
| layer             | o+any                        | open website                                                      | o+f -> create new tab of chrome                                            |          |                                            |
| layer             | a+h/j/k/l/v/b/n              | mouse navigation/click                                            | during navigation: hold f to slow down, hold s to scroll                   |          | avoid pinky problem                        |
| layer             | a+i/o                        | zoom in/out                                                       |                                                                            |          |                                            |
| layer             | t+any                        | toggle setting/information                                        | t+d -> toggle dark mode                                                    |          |                                            |
| layer             | g+h/j/k/l                    | home/page_down/page_up/end                                        |                                                                            |          |                                            |
| layer             | x+h/j/k/l                    | shift+arrow                                                       | vi visual mode                                                             |          |                                            |
| layer             | r+h/j/k/l                    | scrolling                                                         |                                                                            |          |                                            |
| simultaneous keys | j+k                          | esc                                                               |                                                                            | yes      |                                            |
| simultaneous keys | m+k                          | translate                                                         | remap Raycast.app                                                          |          | left hand mode with mouse                  |
| modifier alone    | left cmd                     | cmd+tab                                                           | so easy to switch previous app                                             | yes!     |                                            |
| modifier alone    | right cmd                    | mouse center click to active app, then maximize window            | use it a lot when vimium/ideavim lose focus in chrome/IntelliJ             | yes      |                                            |
| modifier alone    | left option                  | tmux prefix                                                       |                                                                            | yes      |                                            |
| modifier alone    | right option                 | translate in chrome/IntelliJ                                      | remap immersive-translate/Translation                                      | yes      |                                            |
| modifier alone    | left shift                   | switch english/chinese input                                      | by Rime (nothing to do with goku)                                          |          | avoid pinky problem                        |
| modifier alone    | right shift                  | caps_lock                                                         | turn on caps_lock to enter vi mode (in process)                            |          | more vi binding                            |
| modifier alone    | fn                           | copy                                                              |                                                                            |          |                                            |
| modifier alone    | left control                 | paste                                                             |                                                                            |          |                                            |
| other             | caps_lock                    | esc(pressed alone)/control(as modifier)                           | use `j+k` and `v/m+any` instead                                            |          |                                            |
| mouse             | option/command + left click  | copy word/selected                                                |                                                                            |          |                                            |
| mouse             | middle click                 | paste(hold middle click to overwrite)                             |                                                                            |          |                                            |
| trackpad          | s/d + finger on trackpad     | copy word/selected                                                |                                                                            |          | easy to accidentally trigger               |
| trackpad          | f + finger on trackpad       | paste(hold f to overwrite)                                        |                                                                            |          | easy to accidentally trigger               |
| trackpad          | h/j/k/l + finger on trackpad | arrow keys(one finger), home/page_down/page_up/end(two fingers)   |                                                                            |          | easy to accidentally trigger               |

</details>

## [IdeaVim](https://github.com/JetBrains/ideavim)

[.ideavimrc](./dot_ideavimrc)

## [rime-ice](https://github.com/iDvel/rime-ice)

[Rime config](./private_Library/Rime) for Chinese input powered by rime-ice, [flypy](https://flypy.com/) and [TigerCode](https://tiger-code.com/), including:

- 补丁: [雾凇拼音](./private_Library/Rime/rime_ice.custom.yaml), [小鹤双拼](./private_Library/Rime/double_pinyin_flypy.custom.yaml)
- 方案 + 补丁: [小鹤音形](./private_Library/Rime/flypy.custom.yaml), [虎码](./private_Library/Rime/tiger.custom.yaml)

Using [KeyboardHolder](https://keyboardholder.leavesc.com/zh-cn/) to keep [Squirrel](https://github.com/rime/squirrel) as the only input source on macOS, instead of ABC.

And using [ShowyEdge](https://github.com/pqrs-org/ShowyEdge) to notice when input source automatically changes to ABC.

Using [emacs-rime](https://github.com/DogLooksGood/emacs-rime) in Doom Emacs.

## [SketchyBar](https://github.com/FelixKratz/SketchyBar)

[sketchybarrc and plugin scripts](./dot_config/sketchybar)

## [VSCodeVim](https://github.com/VSCodeVim/Vim)

[settings.json](./private_Library/private_Application%20Support/private_Code/User/settings.json)

## [Doom Emacs](https://github.com/doomemacs/doomemacs)

[DOOMDIR](./dot_config/doom)

Using [Emacs Plus](https://github.com/d12frosted/homebrew-emacs-plus).
