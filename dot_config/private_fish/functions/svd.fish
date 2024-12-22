function svd --wraps='svn diff -x -p'
    svn diff -x -p $argv | svn_strip_diff_header | delta --line-numbers
end
