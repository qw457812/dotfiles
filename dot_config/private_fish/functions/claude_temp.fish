function claude_temp --wraps=claude
    set -l orig_pwd (pwd)
    set -l tmpdir (mktemp -d -t cc.XXXXXX)
    cd $tmpdir
    # echo "" >CLAUDE.md
    set -lx CLAUDE_CODE_TMPDIR (test -n "$TERMUX_VERSION" && printf %s "$TMPDIR")
    set -lx CLAUDE_CODE_SIMPLE 1
    claude $argv
    cd $orig_pwd
    rm -r $tmpdir
end
