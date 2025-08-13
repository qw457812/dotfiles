if set -q __proxy_ip; and set -q __http_proxy_port; and set -q __socks_proxy_port
    function term_proxy_on
        set -gx https_proxy "http://$__proxy_ip:$__http_proxy_port"
        set -gx http_proxy "http://$__proxy_ip:$__http_proxy_port"
        set -gx all_proxy "socks5://$__proxy_ip:$__socks_proxy_port"
    end
end
