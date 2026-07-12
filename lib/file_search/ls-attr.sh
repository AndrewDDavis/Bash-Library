ls-xattr() {
    # alias that may be more memorable
    ls-attr "$@"
}

ls-attr() {

    : """List file extended attributes, including system ones

        Runs 'getfattr -d -m -', followed by supplied CLI arguments.
    """

    [[ $# -eq 0  || $1 == @(-h|--help) ]] &&
        { docsh -TD; return; }

    local gf_cmd
    gf_cmd=( "$( builtin type -P getfattr )" ) \
        || return 9

    gf_cmd+=( -d -m )

    (
        set -x
        "${gf_cmd[@]}" - "$@"
    )
}
