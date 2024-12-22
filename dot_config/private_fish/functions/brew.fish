function brew --wraps=brew
    command brew $argv

    if string match -r "upgrade|update|outdated" -- $argv
        sketchybar --trigger brew_update
    end
end
