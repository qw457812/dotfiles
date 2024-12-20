complete -c svld -f -a "(svn log -q | grep '^r' | cut -d' ' -f1)" -d Revision
