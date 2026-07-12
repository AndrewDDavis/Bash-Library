man-web() {

    [[ $# -eq 0 || $1 == @(-h|--help) ]] && {

        docsh -TD """Read man pages from the web

        Uses text based browsers links2 or w3m.

        Usage: man-web [-u] name

        Options

          -u: use ubuntu source (default debian)

        Example

          man-web w3m
        """
        return 0
    }

    local url="https://manpages.debian.org/jump?q="

    [[ $1 == '-u' ]] && {
        url="http://manpages.ubuntu.com/cgi-bin/search.py?q="
        shift
    }

    local name=$1
    shift

    local cmd cmds=( w3m links2 links elinks )

    for cmd in "${cmds[@]}"
    do
        if command -v "$cmd" >/dev/null
        then
            break
        else
            cmd=''
        fi
    done

    [[ -z ${cmd:-} ]] &&
        { err_msg 2 "nothing found from ${cmds[*]}"; return; }

    "$cmd" "${url}${name}"
}
