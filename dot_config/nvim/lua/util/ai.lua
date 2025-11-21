---@class util.ai
local M = {}

-- https://github.com/farion1231/cc-switch/blob/7fa0a7b16648e99ef956d18c01f686dd50e843ed/src/config/claudeProviderPresets.ts
M.claude = {
  provider = {
    plan = {
      anthropic = {
        ANTHROPIC_BASE_URL = vim.env.CTOK_BASE_URL,
        ANTHROPIC_AUTH_TOKEN = vim.env.CTOK_AUTH_TOKEN,
      },
      kimi = {
        ANTHROPIC_BASE_URL = "https://api.kimi.com/coding/",
        ANTHROPIC_AUTH_TOKEN = vim.env.KIMI_API_KEY,
      },
    },
    payg = {
      kimi = {
        ANTHROPIC_BASE_URL = "https://api.moonshot.cn/anthropic",
        ANTHROPIC_AUTH_TOKEN = vim.env.MOONSHOT_API_KEY,
        ANTHROPIC_MODEL = "kimi-k2-thinking-turbo",
        ANTHROPIC_DEFAULT_OPUS_MODEL = "kimi-k2-thinking-turbo",
        ANTHROPIC_DEFAULT_SONNET_MODEL = "kimi-k2-thinking-turbo",
        ANTHROPIC_DEFAULT_HAIKU_MODEL = "kimi-k2-thinking-turbo",
        CLAUDE_CODE_SUBAGENT_MODEL = "kimi-k2-thinking-turbo",
      },
      glm = {
        ANTHROPIC_BASE_URL = "https://open.bigmodel.cn/api/anthropic",
        ANTHROPIC_AUTH_TOKEN = vim.env.ZHIPU_API_KEY,
        API_TIMEOUT_MS = "3000000",
      },
      minimax = {
        ANTHROPIC_BASE_URL = "https://api.minimax.io/anthropic",
        ANTHROPIC_AUTH_TOKEN = vim.env.MINIMAX_API_KEY,
        API_TIMEOUT_MS = "3000000",
        ANTHROPIC_MODEL = "MiniMax-M2",
        ANTHROPIC_SMALL_FAST_MODEL = "MiniMax-M2",
        ANTHROPIC_DEFAULT_SONNET_MODEL = "MiniMax-M2",
        ANTHROPIC_DEFAULT_OPUS_MODEL = "MiniMax-M2",
        ANTHROPIC_DEFAULT_HAIKU_MODEL = "MiniMax-M2",
      },
    },
  },
}

return M
