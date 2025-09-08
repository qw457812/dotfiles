# @fish-lsp-disable 4004
# https://api-docs.deepseek.com/guides/anthropic_api
function claude_deepseek --wraps=claude
    set -lx ANTHROPIC_BASE_URL https://api.deepseek.com/anthropic
    set -lx ANTHROPIC_AUTH_TOKEN $DEEPSEEK_API_KEY
    set -lx API_TIMEOUT_MS 600000
    set -lx ANTHROPIC_MODEL deepseek-chat
    set -lx ANTHROPIC_SMALL_FAST_MODEL deepseek-chat
    command claude $argv
end
