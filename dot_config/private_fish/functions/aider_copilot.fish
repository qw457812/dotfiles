if type -q aider
    function aider_copilot --wraps=aider
        ~/.config/fish/scripts/refresh_copilot_token.fish
        command aider --model copilot $argv
    end
end
