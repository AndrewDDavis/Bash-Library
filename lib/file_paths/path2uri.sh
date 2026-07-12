path2uri() {

    : """Convert file path to URI using Python 3"

    local p script

    for p in "$@"
    do
        script='
import sys, pathlib
print(pathlib.Path(input()).resolve().as_uri())
'
        # or import urllib.parse and use urllib.parse.quote(input())
        python3 -c "$script" <<< "$p"
    done
}
