if type -q aider; and test -f ~/.config/github-copilot/apps.json
    function aider_copilot --wraps=aider
        # this token expires in 30 minutes
        # https://github.com/Aider-AI/aider/issues/2227#issuecomment-2877805565
        # https://github.com/Aider-AI/aider/issues/2227#issuecomment-2884719517
        # https://github.com/Aider-AI/aider/issues/2227#issuecomment-2933308760
        # @fish-lsp-disable-next-line 4004
        set -lx OPENAI_API_KEY (curl -s -H "Authorization: Bearer $(cat ~/.config/github-copilot/apps.json | jq -r 'to_entries[0].value.oauth_token')" "https://api.github.com/copilot_internal/v2/token" | jq -r '.token')
        command aider --model copilot $argv
    end
end
