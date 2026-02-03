# https://platform.moonshot.cn/docs/guide/agent-support
# https://platform.moonshot.ai/docs/guide/agent-support
function claude_kimi --wraps=claude
    set -lx ANTHROPIC_BASE_URL https://api.moonshot.cn/anthropic
    set -lx ANTHROPIC_AUTH_TOKEN $MOONSHOT_API_KEY
    set -lx ANTHROPIC_MODEL kimi-k2-thinking-turbo
    set -lx ANTHROPIC_DEFAULT_OPUS_MODEL kimi-k2-thinking-turbo
    set -lx ANTHROPIC_DEFAULT_SONNET_MODEL kimi-k2-thinking-turbo
    set -lx ANTHROPIC_DEFAULT_HAIKU_MODEL kimi-k2-thinking-turbo
    set -lx CLAUDE_CODE_SUBAGENT_MODEL kimi-k2-thinking-turbo
    command claude $argv
end

# # https://www.kimi.com/code/docs/more/third-party-agents.html
# function claude_kimi --wraps=claude
#     set -lx ANTHROPIC_BASE_URL https://api.kimi.com/coding/
#     set -lx ANTHROPIC_AUTH_TOKEN $KIMI_API_KEY
#     command claude $argv
# end
