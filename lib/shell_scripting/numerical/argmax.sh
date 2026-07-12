argmax() {

    [[ $# -eq 0  || $1 == @(-h|--help) ]] && {

        : """Print maximum value of arguments

        Usage: argmax <number> ...

        Integers only.
        """
        docsh -TD
        return
    }

    (( $# > 0 )) \
        || return 5

    is_int "$1" \
        || { err_msg 2 "not an integer: '$1'"; return; }

    local v vmax
    vmax=$1
    shift

    for v in "$@"
    do
        is_int "$v" \
            || { err_msg 2 "not an integer: '$v'"; return; }

        (( v > vmax )) \
            && vmax=$v
    done

    printf '%s\n' "$vmax"
}
