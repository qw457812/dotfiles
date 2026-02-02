function claude_crs --wraps=claude
    set -lx ANTHROPIC_BASE_URL $CLAUDE_RELAY_SERVICE_URL/api
    set -lx ANTHROPIC_AUTH_TOKEN $CLAUDE_RELAY_SERVICE_API_KEY
    command claude $argv
end
