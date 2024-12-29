function sys_proxy_off
    networksetup -setwebproxystate Wi-Fi off
    networksetup -setsecurewebproxystate Wi-Fi off
    networksetup -setsocksfirewallproxystate Wi-Fi off
end
