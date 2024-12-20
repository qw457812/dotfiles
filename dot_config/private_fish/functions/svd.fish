function svd
    svn diff -x -p $argv | svn_strip_diff_header | delta --line-numbers
end
