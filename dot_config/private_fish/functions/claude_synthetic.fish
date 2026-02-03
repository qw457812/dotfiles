function claude_synthetic --wraps=claude
    # https://dev.synthetic.new/docs/guides/claude-code
    # https://dev.synthetic.new/docs/api/models
    set -lx ANTHROPIC_BASE_URL https://api.synthetic.new/anthropic
    set -lx ANTHROPIC_AUTH_TOKEN $SYNTHETIC_API_KEY
    set -lx ANTHROPIC_DEFAULT_OPUS_MODEL hf:moonshotai/Kimi-K2.5
    set -lx ANTHROPIC_DEFAULT_SONNET_MODEL hf:moonshotai/Kimi-K2.5
    # set -lx ANTHROPIC_DEFAULT_HAIKU_MODEL hf:MiniMaxAI/MiniMax-M2.1
    set -lx ANTHROPIC_DEFAULT_HAIKU_MODEL hf:moonshotai/Kimi-K2.5
    set -lx CLAUDE_CODE_SUBAGENT_MODEL hf:moonshotai/Kimi-K2.5
    command claude $argv
end
