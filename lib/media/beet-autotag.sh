beet-autotag() {

    : """Write tags to files on disk

    Usage: beet-autotag [-s] <path ...>

    This function uses the beets auto-tagging feature to write new file
    metadata, but does not rename or move the files. It also writes to a
    temporary library database file, so the main beets database is not
    affected.

    The paths can be directories, or singleton files with -s.

    To do the same task, but rename the files too, you could use, e.g.:
    beet -l ./db.db -d ./ import [-s] ...
    """

    [[ $# -lt 1  || $1 == @(-h|--help) ]] &&
        { docsh -TD; return; }

    local beet_cmd
    beet_cmd=$( builtin type -P beet ) \
        || return

    # temp database file
    local fn
    fn=$( command mktemp --suffix=.db ) \
        || return

    trap '
        trap - return
        printf >&2 "%s\n" "Cleaning temp db file: $fn"
        /bin/rm -f "$fn"
    ' RETURN

    "$beet_cmd" -l "$fn" import -C "$@"
    # -C: no copy to music dir
}
