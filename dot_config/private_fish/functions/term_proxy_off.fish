function term_proxy_off
    set -e http_proxy
    set -e HTTP_PROXY

    set -e https_proxy
    set -e HTTPS_PROXY

    set -e all_proxy
    set -e ALL_PROXY

    set -e no_proxy
    set -e NO_PROXY

    set -e NODE_USE_ENV_PROXY
end
