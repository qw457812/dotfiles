function claude_fireworks --wraps=claude
    # https://docs.fireworks.ai/firepass
    # https://docs.fireworks.ai/ecosystem/integrations/claude-code
    set -lx ANTHROPIC_BASE_URL https://api.fireworks.ai/inference
    set -lx ANTHROPIC_AUTH_TOKEN $FIREWORKS_API_KEY
    set -lx ANTHROPIC_DEFAULT_OPUS_MODEL accounts/fireworks/routers/kimi-k2p5-turbo
    set -lx ANTHROPIC_DEFAULT_SONNET_MODEL accounts/fireworks/routers/kimi-k2p5-turbo
    set -lx ANTHROPIC_DEFAULT_HAIKU_MODEL accounts/fireworks/routers/kimi-k2p5-turbo
    set -lx ANTHROPIC_MODEL accounts/fireworks/routers/kimi-k2p5-turbo
    set -lx CLAUDE_CODE_DISABLE_EXPERIMENTAL_BETAS 1

    set -lx CLAUDE_CODE_TMPDIR (test -n "$TERMUX_VERSION" && printf %s "$TMPDIR")
    command claude $argv
end
