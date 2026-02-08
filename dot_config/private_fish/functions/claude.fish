function claude --wraps=claude
    if test -n "$TERMUX_VERSION"
        claude_synthetic $argv
    else
        claude_litellm $argv
    end
end
