function svld
    if test -z "$argv[1]" || test (string sub -l 1 -- "$argv[1]") = -
        svn log -v --diff -x '-p -w --ignore-eol-style' $argv | svn_strip_diff_header | delta --line-numbers
    else
        svn log -v --diff -x '-p -w --ignore-eol-style' -r $argv | svn_strip_diff_header | delta --line-numbers
    end
end

function __complete_svld
    svn log -q -l 15 | grep '^r' | cut -d' ' -f1
end

complete -c svld -f -k -a "(__complete_svld)"
