# https://docs.litellm.ai/docs/tutorials/claude_responses_api
function claude_litellm --wraps=claude
    set -lx ANTHROPIC_BASE_URL http://localhost:4000
    set -lx ANTHROPIC_AUTH_TOKEN $LITELLM_MASTER_KEY

    # Fix Synthetic API Error for Claude Code 2.1.63
    set -lx CLAUDE_CODE_DISABLE_ADAPTIVE_THINKING 1
    set -lx MAX_THINKING_TOKENS 31999

    command claude $argv
end
