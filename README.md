# My personal dotfiles on macOS

Manage dotfiles use [chezmoi](https://github.com/twpayne/chezmoi).

## [Goku](https://github.com/yqrashawn/GokuRakuJoudo)

Hack my keyboard use [Karabiner](https://github.com/pqrs-org/Karabiner-Elements), and maintain [**__my karabiner config__**](./dot_config/karabiner.edn) with Goku.

Head over to [nikitavoloboev](https://github.com/nikitavoloboev)'s [**__personal wiki__**](https://wiki.nikiv.dev/macOS/apps/karabiner/) to learn more about karabiner and goku.

Tracking my keyboard input use [WhatPulse](https://whatpulse.org/) to observe.

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
| other             | caps_lock                    | esc(pressed alone)/control(as modifier)                           | use j+k and v/m+any instead                                                |          |                                            |
| mouse             | option/command + left click  | copy word/selected                                                |                                                                            |          |                                            |
| mouse             | middle click                 | paste(hold middle click to overwrite)                             |                                                                            |          |                                            |
| trackpad          | s/d + finger on trackpad     | copy word/selected                                                |                                                                            |          | easy to accidentally trigger               |
| trackpad          | f + finger on trackpad       | paste(hold f to overwrite)                                        |                                                                            |          | easy to accidentally trigger               |
| trackpad          | h/j/k/l + finger on trackpad | arrow keys(one finger), home/page_down/page_up/end(two fingers)   |                                                                            |          | easy to accidentally trigger               |
</details>

## [IdeaVim](https://github.com/JetBrains/ideavim)

[.ideavimrc](./dot_ideavimrc)

## [rime-ice](https://github.com/iDvel/rime-ice)

[Rime config](./private_Library/Rime) for Chinese input power by rime-ice and [flypy](https://flypy.com/), including:
- 补丁: 雾凇拼音, 小鹤双拼
- 方案: 小鹤音形

## [SketchyBar](https://github.com/FelixKratz/SketchyBar)

[sketchybarrc and plugin scripts](./dot_config/sketchybar)

## [vscode](https://code.visualstudio.com/)

[settings.json](./private_Library/private_Application%20Support/private_Code/User/settings.json)
