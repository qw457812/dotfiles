# # copied from: https://github.com/folke/dot/blob/cb1d6f956e0ef1848e57a57c1678d8635980d6c5/config/fish/functions/fish_title.fish
# # nerd-fonts: https://www.nerdfonts.com/cheat-sheet
# function __fish_title_icon
#     set -l cmd $argv[1]
#     switch $cmd
#         case fish
#             set cmd " "
#         case nvim vim
#             set cmd " "
#         case gh
#             set cmd " "
#         case lazygit git
#             set cmd " "
#         case topgrade
#             set cmd " "
#         case htop btop
#             set cmd "󰄧 "
#         case curl wget
#             set cmd " "
#         case cargo
#             set cmd " "
#         case docker docker-compose lazydocker
#             set cmd " "
#         case make
#             set cmd " "
#         case node
#             set cmd " "
#         case pacman paru
#             set cmd "󰮯 "
#     end
#     echo $cmd
# end

# emoji: https://emojicombos.com/
function __fish_title_icon
    set -l cmd $argv[1]
    switch $cmd
        case fish
            set cmd "🐟 "
        case nvim vim
            set cmd "📝 "
        case gh
            set cmd "🐙 "
        case git lazygit
            set cmd "🌿 "
        case topgrade
            set cmd "🔄 "
        case htop btop
            set cmd "📊 "
        case curl wget
            set cmd "🌐 "
        case cargo
            set cmd "📦 "
        case docker docker-compose lazydocker
            set cmd "🐳 "
        case make
            set cmd "🛠️ "
        case node
            set cmd "🌲 "
        case pacman paru
            set cmd "📦 "
    end
    echo $cmd
end

# copied from: https://github.com/fish-shell/fish-shell/blob/6c63139d23ab95339981d50954660c6a1255f374/share/functions/fish_title.fish
function fish_title
    # If we're connected via ssh, we print the hostname.
    set -l ssh
    set -q SSH_TTY
    and set ssh "["(prompt_hostname | string sub -l 10 | string collect)"]"
    # An override for the current command is passed as the first parameter.
    # This is used by `fg` to show the true process name, among others.
    if set -q argv[1]
        echo -- $ssh (string sub -l 20 -- (__fish_title_icon $argv[1])) (prompt_pwd -d 1 -D 1)
    else
        # Don't print "fish" because it's redundant
        set -l command (status current-command)
        if test "$command" = fish
            set command
        end
        echo -- $ssh (string sub -l 20 -- (__fish_title_icon $command)) (prompt_pwd -d 1 -D 1)
    end
end
