# https://docs.bigmodel.cn/cn/guide/develop/claude
# https://docs.bigmodel.cn/cn/coding-plan/tool/claude
# https://docs.z.ai/scenario-example/develop-tools/claude
function claude_glm --wraps=claude
    set -lx ANTHROPIC_BASE_URL https://api.z.ai/api/anthropic
    set -lx ANTHROPIC_AUTH_TOKEN $ZAI_API_KEY

    # set -lx ANTHROPIC_BASE_URL https://open.bigmodel.cn/api/anthropic
    # set -lx ANTHROPIC_AUTH_TOKEN $ZHIPU_API_KEY

    set -lx API_TIMEOUT_MS 3000000
    set -lx ANTHROPIC_DEFAULT_OPUS_MODEL glm-5
    set -lx ANTHROPIC_DEFAULT_SONNET_MODEL glm-5
    set -lx ANTHROPIC_DEFAULT_HAIKU_MODEL glm-4.7 # glm-4.5-air is not good enough
    command claude $argv
end
