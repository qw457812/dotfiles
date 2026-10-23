# One entry point for the local proxy: macOS system proxy + shell env vars.
# On Linux the TUN device already covers everything, so the system part is a
# no-op there and only the env vars remain useful.
#
#   proxy on                system proxy on  + export env vars
#   proxy off               system proxy off + unset env vars
#   proxy status            endpoint, listener, system state, env state
#   proxy env on|off        env vars only
#   proxy env auto          export only if something listens on the port
#
# Override the endpoint with: set -g __PROXY_HOST <host>; set -g __PROXY_PORT <port>
#
# Reference: the networksetup workflow follows v2rayN's sample script,
# https://github.com/2dust/v2rayN/blob/57f17d5939e88c8e643ab49b90869d637765e75a/v2rayN/ServiceLib/Sample/proxy_set_osx_sh
# (iterate every enabled service, set web/secure/socks, then the bypass list).

set -q __PROXY_HOST; or set -g __PROXY_HOST 127.0.0.1
set -q __PROXY_PORT; or set -g __PROXY_PORT 10808

function __proxy_bypass --description 'hosts and CIDRs that skip the proxy'
    # `localhost 127.0.0.0/8 ::1` is what v2rayN sets by default. The RFC1918
    # ranges and `*.local` are additions: mihomo already sends geoip:private
    # DIRECT, so these only save a hop through the local port.
    printf '%s\n' localhost 127.0.0.0/8 ::1 \
        10.0.0.0/8 172.16.0.0/12 192.168.0.0/16 '*.local'
end

function __proxy_services --description 'enabled macOS network services'
    networksetup -listallnetworkservices | tail -n +2 | string match -rv '^\*'
end

function __proxy_listening
    lsof -nP -iTCP:$__PROXY_PORT -sTCP:LISTEN >/dev/null 2>&1
end

function __proxy_sys_on
    if not type -q networksetup
        echo 'proxy: no system proxy backend (TUN covers it on Linux)' >&2
        return 0
    end
    for svc in (__proxy_services)
        networksetup -setwebproxy           "$svc" $__PROXY_HOST $__PROXY_PORT
        networksetup -setsecurewebproxy     "$svc" $__PROXY_HOST $__PROXY_PORT
        networksetup -setsocksfirewallproxy "$svc" $__PROXY_HOST $__PROXY_PORT
        networksetup -setproxybypassdomains "$svc" (__proxy_bypass)
        networksetup -setwebproxystate           "$svc" on
        networksetup -setsecurewebproxystate     "$svc" on
        networksetup -setsocksfirewallproxystate "$svc" on
    end
    echo "proxy: system -> $__PROXY_HOST:$__PROXY_PORT"
end

function __proxy_sys_off
    type -q networksetup; or return 0
    for svc in (__proxy_services)
        networksetup -setwebproxystate           "$svc" off
        networksetup -setsecurewebproxystate     "$svc" off
        networksetup -setsocksfirewallproxystate "$svc" off
    end
    echo 'proxy: system off'
end

function __proxy_env_on
    set -gx http_proxy  "http://$__PROXY_HOST:$__PROXY_PORT"
    set -gx HTTP_PROXY  $http_proxy
    set -gx https_proxy "http://$__PROXY_HOST:$__PROXY_PORT"
    set -gx HTTPS_PROXY $https_proxy
    set -gx all_proxy   "socks5://$__PROXY_HOST:$__PROXY_PORT"
    set -gx ALL_PROXY   $all_proxy
    set -gx no_proxy    'localhost,127.0.0.1'
    set -gx NO_PROXY    $no_proxy
    set -gx NODE_USE_ENV_PROXY 1
end

function __proxy_env_off
    set -e http_proxy HTTP_PROXY https_proxy HTTPS_PROXY \
           all_proxy ALL_PROXY no_proxy NO_PROXY NODE_USE_ENV_PROXY
end

function __proxy_status
    printf 'endpoint : %s:%s\n' $__PROXY_HOST $__PROXY_PORT
    __proxy_listening; and printf 'listener : up\n'; or printf 'listener : down\n'
    if type -q networksetup
        set -l state off
        scutil --proxy | string match -rq '^\s+HTTPEnable : 1'; and set state on
        printf 'system   : %s\n' $state
        scutil --proxy \
            | string match -r '^\s+(?:HTTP|HTTPS|SOCKS)(?:Enable|Proxy|Port) : .*' \
            | string replace -r '^\s+' '           '
    else
        printf 'system   : n/a on this platform (TUN is the transport)\n'
    end
    set -q http_proxy; and printf 'env      : %s\n' $http_proxy; or printf 'env      : off\n'
end

function proxy --description 'Local proxy: on | off | status | env on|auto|off'
    switch "$argv[1]"
        case on
            __proxy_listening; or echo "proxy: nothing listening on $__PROXY_PORT" >&2
            __proxy_sys_on
            __proxy_env_on
        case off
            __proxy_sys_off
            __proxy_env_off
        case status
            __proxy_status
        case env
            switch "$argv[2]"
                case on
                    __proxy_env_on
                case off
                    __proxy_env_off
                case auto
                    if __proxy_listening
                        __proxy_env_on
                    else
                        __proxy_env_off
                    end
                case '*'
                    echo 'usage: proxy env on|auto|off' >&2
                    return 1
            end
        case '*'
            echo 'usage: proxy on|off|status|env on|auto|off' >&2
            return 1
    end
end
