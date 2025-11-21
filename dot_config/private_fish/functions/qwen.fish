function qwen --wraps=qwen
    set -lx OPENAI_BASE_URL "https://api-inference.modelscope.cn/v1"
    set -lx OPENAI_API_KEY $MODELSCOPE_API_KEY
    set -lx OPENAI_MODEL Qwen/Qwen3-Coder-480B-A35B-Instruct
    command qwen $argv
end
