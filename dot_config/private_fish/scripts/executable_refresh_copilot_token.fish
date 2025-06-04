#!/usr/bin/env fish

# add to crontab as this token expires in 30 minutes (not working and not needed for aider, removed from crontab)
# */25 * * * * ~/.config/fish/scripts/refresh_copilot_token.fish >/dev/null 2>&1

if test -f ~/.config/github-copilot/apps.json
    # https://github.com/Aider-AI/aider/issues/2227#issuecomment-2877805565
    # https://github.com/Aider-AI/aider/issues/2227#issuecomment-2884719517
    # https://github.com/Aider-AI/aider/issues/2227#issuecomment-2933308760
    set -Ux OPENAI_API_KEY (curl -s -H "Authorization: Bearer $(cat ~/.config/github-copilot/apps.json | jq -r 'to_entries[0].value.oauth_token')" "https://api.github.com/copilot_internal/v2/token" | jq -r '.token')
end
