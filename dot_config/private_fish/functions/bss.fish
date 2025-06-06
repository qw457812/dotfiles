function bss --wraps='brew services start'
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

# complete -c bss -f -a "(brew services list --json | jq -r '.[].name')"
