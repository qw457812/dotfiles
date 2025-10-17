# @fish-lsp-disable 4004
# https://platform.moonshot.cn/docs/guide/agent-support
function claude_kimi --wraps=claude
    set -lx ANTHROPIC_BASE_URL https://api.moonshot.cn/anthropic
    set -lx ANTHROPIC_AUTH_TOKEN $MOONSHOT_API_KEY
    set -lx ANTHROPIC_MODEL kimi-k2-0905-preview
    set -lx ANTHROPIC_SMALL_FAST_MODEL kimi-k2-turbo-preview
    command claude $argv
end
