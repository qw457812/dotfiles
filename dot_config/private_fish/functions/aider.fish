function aider --wraps=aider
    ~/.config/fish/scripts/refresh_copilot_token.fish
    command aider $argv
end
