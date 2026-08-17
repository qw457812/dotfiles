if set -q __proxy_ip; and set -q __http_proxy_port; and set -q __socks_proxy_port
    function term_proxy_on
        set -gx http_proxy "http://$__proxy_ip:$__http_proxy_port"
        set -gx HTTP_PROXY $http_proxy

        set -gx https_proxy "http://$__proxy_ip:$__http_proxy_port"
        set -gx HTTPS_PROXY $https_proxy

        set -gx all_proxy "socks5://$__proxy_ip:$__socks_proxy_port"
        set -gx ALL_PROXY $all_proxy

        set -gx no_proxy "localhost,127.0.0.1"
        set -gx NO_PROXY $no_proxy

        # for `dsh plugin --profile dsh-tui exec dsh-openai-codex login`
        # https://github.com/Yan-Zero/dsh-codex
        set -gx NODE_USE_ENV_PROXY 1
    end
end
