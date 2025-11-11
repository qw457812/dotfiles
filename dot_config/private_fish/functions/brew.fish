type -q brew; or return

function brew --wraps=brew
    command brew $argv

    if string match -q -r "upgrade|update|outdated" -- $argv
        type -q sketchybar; and sketchybar --trigger brew_update
    end
end
