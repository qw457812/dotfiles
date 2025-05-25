# copilot
# https://github.com/Aider-AI/aider/issues/2227#issuecomment-2877805565
# https://github.com/Aider-AI/aider/issues/2227#issuecomment-2884719517
set -Ux OPENAI_API_KEY (curl -s -H "Authorization: Bearer $(cat ~/.config/github-copilot/apps.json | jq -r 'to_entries[0].value.oauth_token')" "https://api.github.com/copilot_internal/v2/token" | jq -r '.token')
