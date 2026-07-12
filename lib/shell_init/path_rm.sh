: """Print new PATH with an element removed

    Usage: path_rm <path> ...

    All instances of the path are removed from the PATH variable.
"""

path_rm() {

    [[ $# -eq 0  || $1 == @(-h|--help) ]] \
        && { docsh -TD; return; }

    local pp
    for pp in "$@"
    do
        # pp may be the whole path, the first or last item, or somewhere in the middle
        case "$PATH" in
            ( "$pp" )
                PATH='' ;;
            ( "$pp:"* )
                PATH=${PATH#"${pp}:"} ;;
            ( *":$pp" )
                PATH=${PATH%":${pp}"} ;;
            ( *":$pp:"* )
                PATH=${PATH//:"${pp}":/:} ;;
            ( * )
                err_msg 2 "no match in PATH: '$pp'"
                return ;;
        esac
    done

    printf '%s\n' "$PATH"
}

# or using AWK...
# awk '{ gsub("/home/andrew/Sync/Code/python/misc",""); gsub(/:/,"\n"); print; }' <<< "$PATH"
