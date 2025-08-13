# @fish-lsp-disable 4004
# https://github.com/LLM-Red-Team/kimi-cc
function claude_kimi --wraps=claude
    set -lx ANTHROPIC_BASE_URL https://api.moonshot.cn/anthropic/
    set -lx ANTHROPIC_API_KEY $MOONSHOT_API_KEY
    command claude --model sonnet $argv
end
