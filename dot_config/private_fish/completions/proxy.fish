# Completions for ~/.config/fish/functions/proxy.fish

set -l subcommands on off status env

complete -c proxy -f

complete -c proxy -n "not __fish_seen_subcommand_from $subcommands" -a on     -d 'System proxy on + env vars'
complete -c proxy -n "not __fish_seen_subcommand_from $subcommands" -a off    -d 'System proxy off + clear env'
complete -c proxy -n "not __fish_seen_subcommand_from $subcommands" -a status -d 'Show current state'
complete -c proxy -n "not __fish_seen_subcommand_from $subcommands" -a env    -d 'Env vars only'

complete -c proxy -n "__fish_seen_subcommand_from env" -a on   -d 'Export proxy env vars'
complete -c proxy -n "__fish_seen_subcommand_from env" -a auto -d 'Export only if port is listening'
complete -c proxy -n "__fish_seen_subcommand_from env" -a off  -d 'Unset proxy env vars'
