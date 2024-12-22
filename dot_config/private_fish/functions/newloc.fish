# reload network
function newloc
    set -l old (networksetup -getcurrentlocation)
    set -l new "tmp_"(date '+%Y%m%d_%H%M%S')
    if networksetup -createlocation $new populate >/dev/null; and networksetup -switchtolocation $new >/dev/null; and string match -q "tmp_*" $old
        networksetup -deletelocation $old >/dev/null
    end
end
