complete -c bss -f -a "(brew services list --json | jq -r '.[].name')"
