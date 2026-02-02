function claude --wraps=claude
    set -lx ANTHROPIC_BASE_URL https://api.z.ai/api/anthropic
    set -lx ANTHROPIC_AUTH_TOKEN $ZAI_API_KEY
    command claude $argv
end
