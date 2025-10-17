# @fish-lsp-disable 4004
# https://docs.bigmodel.cn/cn/guide/develop/claude
function claude_glm --wraps=claude
    set -lx ANTHROPIC_BASE_URL https://open.bigmodel.cn/api/anthropic/
    set -lx ANTHROPIC_AUTH_TOKEN $BIGMODEL_API_KEY
    command claude --model sonnet $argv
end

# # https://docs.z.ai/scenario-example/develop-tools/claude
# function claude_glm --wraps=claude
#     set -lx ANTHROPIC_BASE_URL https://api.z.ai/api/anthropic
#     set -lx ANTHROPIC_AUTH_TOKEN $ZAI_API_KEY
#     set -lx API_TIMEOUT_MS 3000000
#     command claude $argv
# end
