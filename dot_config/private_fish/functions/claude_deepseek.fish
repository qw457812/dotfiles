# https://api-docs.deepseek.com/zh-cn/quick_start/agent_integrations/claude_code
function claude_deepseek --wraps=claude
    set -lx ANTHROPIC_BASE_URL https://api.deepseek.com/anthropic
    set -lx ANTHROPIC_AUTH_TOKEN $DEEPSEEK_API_KEY
    set -lx ANTHROPIC_MODEL deepseek-v4-pro[1m]
    set -lx ANTHROPIC_DEFAULT_OPUS_MODEL deepseek-v4-pro[1m]
    set -lx ANTHROPIC_DEFAULT_SONNET_MODEL deepseek-v4-pro[1m]
    set -lx ANTHROPIC_DEFAULT_HAIKU_MODEL deepseek-v4-flash
    set -lx CLAUDE_CODE_EFFORT_LEVEL max
    set -lx CLAUDE_CODE_TMPDIR (test -n "$TERMUX_VERSION" && printf %s "$TMPDIR")
    command claude $argv
end
