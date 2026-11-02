complete -c win-proxy -f
complete -c win-proxy -n 'not __fish_seen_subcommand_from start stop status' -a start -d 'Start the Windows SOCKS tunnel'
complete -c win-proxy -n 'not __fish_seen_subcommand_from start stop status' -a stop -d 'Stop the Windows SOCKS tunnel'
complete -c win-proxy -n 'not __fish_seen_subcommand_from start stop status' -a status -d 'Show tunnel status'
