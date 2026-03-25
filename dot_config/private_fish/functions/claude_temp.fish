function claude_temp --wraps=claude
    set -l orig_pwd (pwd)
    set -l tmpdir (mktemp -d -t cc.XXXXXX)
    cd $tmpdir
    # printf "# Language\nAlways respond in Chinese. Use Chinese for all explanations, comments, and communications with the user. Technical terms and code identifiers should remain in their original form.\n" >CLAUDE.md
    set -lx CLAUDE_CODE_TMPDIR (test -n "$TERMUX_VERSION" && printf %s "$TMPDIR")
    # set -lx CLAUDE_CODE_SIMPLE 1
    claude $argv
    cd $orig_pwd
    rm -r $tmpdir
end
