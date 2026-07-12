beet-rename() {

    : """Rename files on disk, and update the path in the beets library

    Usage: beet-rename <oldpath> <newpath>

    beet will ask for confirmation first.
    """

    [[ $# -lt 2  || $1 == @(-h|--help) ]] &&
        { docsh -TD; return; }

    local beet_cmd
    beet_cmd=$( builtin type -P beet ) \
        || return

    /bin/mv -v "$1" "$2" \
        || return

    "$beet_cmd" modify -M "path:$1" "path=$2"
}
