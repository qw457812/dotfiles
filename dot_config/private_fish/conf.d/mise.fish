if set -q TERMUX_VERSION
    set -gx MISE_DISABLE_TOOLS java,scala,python,node,pnpm,bun
    set -gx MISE_LOCKFILE 0
end

if not type -q mise
    return
end

# mise is automatically activated when using brew and fish
if type -q brew; and string match -q (brew --prefix)"/*" (which mise)
    return
end

mise activate fish | source
