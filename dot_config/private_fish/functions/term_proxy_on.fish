function term_proxy_on
    set -gx https_proxy "http://$__proxy_ip:$__http_proxy_port"
    set -gx http_proxy "http://$__proxy_ip:$__http_proxy_port"
    set -gx all_proxy "socks5://$__proxy_ip:$__socks_proxy_port"
end
