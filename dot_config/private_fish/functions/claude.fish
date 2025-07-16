# https://github.com/LLM-Red-Team/kimi-cc
function claude --wraps=claude
    set -lx ANTHROPIC_BASE_URL https://api.moonshot.cn/anthropic/
    set -lx ANTHROPIC_API_KEY $MOONSHOT_API_KEY
    command claude $argv
end
