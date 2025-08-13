# @fish-lsp-disable 4004
# https://qwenlm.github.io/blog/qwen3-coder/
function claude_qwen --wraps=claude
    set -lx ANTHROPIC_BASE_URL https://dashscope.aliyuncs.com/api/v2/apps/claude-code-proxy/
    set -lx ANTHROPIC_AUTH_TOKEN $DASHSCOPE_API_KEY
    command claude --model sonnet $argv
end
