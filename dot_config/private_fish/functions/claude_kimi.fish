# @fish-lsp-disable 4004

# # https://platform.moonshot.cn/docs/guide/agent-support
# # https://platform.moonshot.ai/docs/guide/agent-support
# function claude_kimi --wraps=claude
#     set -lx ANTHROPIC_BASE_URL https://api.moonshot.cn/anthropic
#     set -lx ANTHROPIC_AUTH_TOKEN $MOONSHOT_API_KEY
#     # set -lx ANTHROPIC_MODEL kimi-k2-0905-preview
#     set -lx ANTHROPIC_MODEL kimi-k2-turbo-preview
#     set -lx ANTHROPIC_SMALL_FAST_MODEL kimi-k2-turbo-preview
#     command claude $argv
# end

# https://www.kimi.com/coding/docs/third-party-agents.html
function claude_kimi --wraps=claude
    set -lx ANTHROPIC_BASE_URL https://api.kimi.com/coding/
    set -lx ANTHROPIC_AUTH_TOKEN $KIMI_API_KEY
    set -lx ANTHROPIC_MODEL kimi-for-coding
    set -lx ANTHROPIC_SMALL_FAST_MODEL kimi-for-coding
    command claude $argv
end
