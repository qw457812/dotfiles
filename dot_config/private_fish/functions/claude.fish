# @fish-lsp-disable 4004
function claude --wraps=claude
    # set -lx ANTHROPIC_BASE_URL https://tokhub.ai
    # set -lx ANTHROPIC_API_KEY $TOKHUB_API_KEY

    # https://us.ctok.ai/api/
    # https://hk.ctok.ai/api/
    set -lx ANTHROPIC_BASE_URL https://us.ctok.ai/api/
    set -lx ANTHROPIC_AUTH_TOKEN $CTOK_AUTH_TOKEN

    # command claude --verbose $argv
    command claude $argv
end
