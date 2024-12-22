# https://wiki.vifm.info/index.php/How_to_set_shell_working_directory_after_leaving_Vifm
function ff --wraps=vifm
    set dst "$(command vifm --choose-dir - $argv[2..-1])"
    if [ -z "$dst" ]
        echo 'Directory picking cancelled/failed'
        return 1
    end
    cd "$dst"
end
