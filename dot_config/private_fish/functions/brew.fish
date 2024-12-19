function brew
    command brew $argv

    if string match -r "upgrade|update|outdated" -- $argv
        sketchybar --trigger brew_update
    end
end

function bss
    if test (count $argv) -eq 0
        brew services
    else
        set service_status (brew services info $argv --json | jq -r '.[].status')
        if test "$service_status" = started
            brew services stop $argv
        else
            brew services start $argv
        end
    end
end
