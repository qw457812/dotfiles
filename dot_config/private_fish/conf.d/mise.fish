if not type -q mise
    return
end

# mise is automatically activated when using brew and fish
if type -q brew; and string match -q (brew --prefix)"/*" (which mise)
    return
end

mise activate fish | source
