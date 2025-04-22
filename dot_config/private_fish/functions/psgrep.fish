# https://github.com/ohmyzsh/ohmyzsh/blob/c1679a12f819f99dd5c6ca801e013e3be597d1a9/plugins/systemadmin/systemadmin.plugin.zsh#L49-L51
function psgrep --wraps=grep
    ps aux | grep -v grep | grep $argv
end
