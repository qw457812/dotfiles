function win-proxy --description 'Manage the Windows SOCKS tunnel'
    set -l socket "$XDG_RUNTIME_DIR/win-proxy.sock"
    set -l port 20880

    if not set -q XDG_RUNTIME_DIR; or not test -d "$XDG_RUNTIME_DIR"
        echo 'win-proxy: XDG_RUNTIME_DIR is unavailable' >&2
        return 1
    end

    if test (count $argv) -ne 1
        echo 'Usage: win-proxy start|stop|status' >&2
        return 2
    end

    switch $argv[1]
        case start
            if command ssh -S "$socket" -O check win-vm >/dev/null 2>&1
                echo "win-proxy: tunnel is already running on 127.0.0.1:$port"
                return 0
            end
            if command nc -z -w 1 127.0.0.1 $port >/dev/null 2>&1
                echo "win-proxy: port 127.0.0.1:$port is already in use" >&2
                return 1
            end
            command ssh -M -S "$socket" -o ControlPersist=no -o ExitOnForwardFailure=yes \
                -f -N -D 127.0.0.1:$port win-vm; or return
            echo "win-proxy: tunnel started on 127.0.0.1:$port"
        case stop
            if not command ssh -S "$socket" -O check win-vm >/dev/null 2>&1
                echo 'win-proxy: managed tunnel is not running'
                return 1
            end
            command ssh -S "$socket" -O exit win-vm; or return
            echo 'win-proxy: tunnel stopped'
        case status
            if command ssh -S "$socket" -O check win-vm >/dev/null 2>&1
                echo "win-proxy: tunnel is running on 127.0.0.1:$port"
                echo 'win-proxy: remote network connectivity has not been checked'
            else
                echo 'win-proxy: managed tunnel is not running'
                return 1
            end
        case '*'
            echo 'Usage: win-proxy start|stop|status' >&2
            return 2
    end
end
