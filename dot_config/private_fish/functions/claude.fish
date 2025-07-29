# @fish-lsp-disable 4004
function claude --wraps=claude
    set -lx ANTHROPIC_BASE_URL https://tokhub.ai
    set -lx ANTHROPIC_API_KEY $TOKHUB_API_KEY
    command claude $argv
end
