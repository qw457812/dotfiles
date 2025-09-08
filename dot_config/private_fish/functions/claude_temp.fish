function claude_temp --wraps=claude
    set -l orig_pwd (pwd)
    set -l tmpdir (mktemp -d -t cc.XXXXXX)
    cd $tmpdir
    # echo "" >CLAUDE.md
    claude $argv
    cd $orig_pwd
    rm -r $tmpdir
end
