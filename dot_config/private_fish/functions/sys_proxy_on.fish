function sys_proxy_on
    networksetup -setwebproxy Wi-Fi $__proxy_ip $__http_proxy_port
    networksetup -setsecurewebproxy Wi-Fi $__proxy_ip $__http_proxy_port
    networksetup -setsocksfirewallproxy Wi-Fi $__proxy_ip $__socks_proxy_port
    networksetup -setwebproxystate Wi-Fi on
    networksetup -setsecurewebproxystate Wi-Fi on
    networksetup -setsocksfirewallproxystate Wi-Fi on
end
