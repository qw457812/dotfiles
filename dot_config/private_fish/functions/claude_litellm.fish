# https://docs.litellm.ai/docs/tutorials/claude_responses_api
function claude_litellm --wraps=claude
    set -lx ANTHROPIC_BASE_URL http://localhost:4000
    set -lx ANTHROPIC_AUTH_TOKEN $LITELLM_MASTER_KEY
    set -lx API_TIMEOUT_MS 3000000

    set -lx CLAUDE_CODE_TMPDIR (test -n "$TERMUX_VERSION" && printf %s "$TMPDIR")
    command claude $argv
end
