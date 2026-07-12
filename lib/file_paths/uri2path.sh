uri2path() {

    : """Convert URI to file path using Python 3"

    local u script

    for u in "$@"
    do
        script='
import sys, urllib.parse
print(urllib.parse.unquote(input()))
'
        python3 -c "$script" <<< "${u#file://}"
    done
}
