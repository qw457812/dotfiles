# gather external ip address
# https://github.com/ohmyzsh/ohmyzsh/blob/c1679a12f819f99dd5c6ca801e013e3be597d1a9/plugins/systemadmin/systemadmin.plugin.zsh#L159-L169
function geteip
    curl -s -S -4 https://icanhazip.com

    # handle case when there is no IPv6 external IP, which shows error
    # curl: (7) Couldn't connect to server
    curl -s -S -6 https://icanhazip.com 2>/dev/null
    set -l ret $status
    if test $ret -eq 7
        echo (set_color red)"error: no IPv6 route to host"(set_color normal) >&2
    end
    return $ret
end
