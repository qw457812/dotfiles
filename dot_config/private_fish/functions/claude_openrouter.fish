# https://openrouter.ai/docs/guides/guides/claude-code-integration
function claude_openrouter --wraps=claude
    set -lx ANTHROPIC_BASE_URL https://openrouter.ai/api
    set -lx ANTHROPIC_AUTH_TOKEN $CC_OPENROUTER_API_KEY
    set -lx ANTHROPIC_API_KEY ""
    command claude $argv
end
