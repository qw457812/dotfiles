# https://qwenlm.github.io/blog/qwen3-coder/
function claude_qwen --wraps=claude
    set -lx ANTHROPIC_BASE_URL https://dashscope.aliyuncs.com/api/v2/apps/claude-code-proxy/
    set -lx ANTHROPIC_AUTH_TOKEN $DASHSCOPE_API_KEY
    set -lx CLAUDE_CODE_TMPDIR (test -n "$TERMUX_VERSION" && printf %s "$TMPDIR")
    command claude --model sonnet $argv
end
