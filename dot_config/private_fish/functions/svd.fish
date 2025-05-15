function svd --wraps='svn diff'
    svn diff -x '-p -w --ignore-eol-style' $argv | svn_strip_diff_header | delta --line-numbers
end
