# https://hyper.charm.land/docs/coding-agents/claude-code.html
function claude_hyper --wraps=claude
    set -lx ANTHROPIC_BASE_URL https://hyper.charm.land
    set -lx ANTHROPIC_AUTH_TOKEN $HYPER_API_KEY
    set -lx ANTHROPIC_DEFAULT_OPUS_MODEL kimi-k3
    set -lx ANTHROPIC_DEFAULT_SONNET_MODEL glm-5.3
    set -lx ANTHROPIC_DEFAULT_HAIKU_MODEL glm-5.3-flash
    set -lx ANTHROPIC_MODEL glm-5.3-flash

    set -lx CLAUDE_CODE_TMPDIR (test -n "$TERMUX_VERSION" && printf %s "$TMPDIR")
    command claude $argv
end
