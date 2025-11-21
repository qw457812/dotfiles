function svld
    if test -z "$argv[1]" || test (string sub -l 1 -- "$argv[1]") = -
        svn log -v --diff -x '-p -w --ignore-eol-style' $argv | svn_strip_diff_header | delta --line-numbers
    else
        svn log -v --diff -x '-p -w --ignore-eol-style' -r $argv | svn_strip_diff_header | delta --line-numbers
    end
end

function __complete_svld
    # svn log -q -l 9 | grep '^r' | cut -d' ' -f1
    svn log -l 9 | awk '
        /^r[0-9]+/ {
            rev = $1;
            sub(/^r/, "", rev);
            msg = "";
        }
        /^[^-r]/ && NF > 0 && rev && !msg {
            msg = $0;
        }
        /^------------------------------------------------------------------------$/ && rev {
            if (msg == "") msg = "<empty message>";
            print rev "\t" msg;
            rev = "";
            msg = "";
        }'
end

complete -c svld -f -k -a "(__complete_svld)"
