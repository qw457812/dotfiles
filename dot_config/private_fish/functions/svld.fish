function svld
    if test -z "$argv[1]" || test (string sub -l 1 -- "$argv[1]") = -
        svn log -v --diff $argv | svn_strip_diff_header | delta --line-numbers
    else
        svn log -v --diff -r $argv | svn_strip_diff_header | delta --line-numbers
    end
end
