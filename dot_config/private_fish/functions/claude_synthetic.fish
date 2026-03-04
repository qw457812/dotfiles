function claude_synthetic --wraps=claude
    # https://dev.synthetic.new/docs/guides/claude-code
    # https://dev.synthetic.new/docs/api/models
    set -lx ANTHROPIC_BASE_URL https://api.synthetic.new/anthropic
    set -lx ANTHROPIC_AUTH_TOKEN $SYNTHETIC_API_KEY
    set -lx ANTHROPIC_DEFAULT_OPUS_MODEL hf:moonshotai/Kimi-K2.5
    set -lx ANTHROPIC_DEFAULT_SONNET_MODEL hf:nvidia/Kimi-K2.5-NVFP4
    set -lx ANTHROPIC_DEFAULT_HAIKU_MODEL hf:MiniMaxAI/MiniMax-M2.5

    # Fix Synthetic API Error for Claude Code 2.1.63
    set -lx CLAUDE_CODE_DISABLE_ADAPTIVE_THINKING 1
    set -lx MAX_THINKING_TOKENS 31999

    # https://github.com/anthropics/claude-code/issues/18342#issuecomment-3936122160
    set -lx CLAUDE_CODE_TMPDIR (test -n "$TERMUX_VERSION" && printf %s "$TMPDIR")
    command claude $argv
end
