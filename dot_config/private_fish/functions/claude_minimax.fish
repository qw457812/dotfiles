# https://platform.minimaxi.com/docs/guides/text-ai-coding-tools
# https://platform.minimax.io/docs/guides/text-ai-coding-tools#use-minimax-m2-in-claude-code-recommended
function claude_minimax --wraps=claude
    set -lx ANTHROPIC_BASE_URL https://api.minimaxi.com/anthropic
    set -lx ANTHROPIC_AUTH_TOKEN $MINIMAX_API_KEY
    set -lx API_TIMEOUT_MS 3000000
    set -lx ANTHROPIC_MODEL MiniMax-M2
    set -lx ANTHROPIC_SMALL_FAST_MODEL MiniMax-M2
    set -lx ANTHROPIC_DEFAULT_SONNET_MODEL MiniMax-M2
    set -lx ANTHROPIC_DEFAULT_OPUS_MODEL MiniMax-M2
    set -lx ANTHROPIC_DEFAULT_HAIKU_MODEL MiniMax-M2
    command claude $argv
end
