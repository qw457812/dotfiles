# @fish-lsp-disable 4004
function claude --wraps=claude
    # set -lx ANTHROPIC_BASE_URL https://tokhub.ai
    # set -lx ANTHROPIC_API_KEY $TOKHUB_API_KEY
    set -lx ANTHROPIC_BASE_URL https://claude.ctok.ai/api/ # https://us.ctok.ai/api/
    set -lx ANTHROPIC_AUTH_TOKEN $CTOK_AUTH_TOKEN
    # command claude --verbose $argv
    command claude $argv
end
