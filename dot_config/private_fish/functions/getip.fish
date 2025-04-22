# determine local IP address(es)
# https://github.com/ohmyzsh/ohmyzsh/blob/c1679a12f819f99dd5c6ca801e013e3be597d1a9/plugins/systemadmin/systemadmin.plugin.zsh#L171-L178
function getip
    ifconfig | awk '/inet /{print $2}' | command grep -v 127.0.0.1
end
