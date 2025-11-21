function claude --wraps=claude
    set -lx ANTHROPIC_BASE_URL $CTOK_BASE_URL
    set -lx ANTHROPIC_AUTH_TOKEN $CTOK_AUTH_TOKEN
    command claude $argv
end
