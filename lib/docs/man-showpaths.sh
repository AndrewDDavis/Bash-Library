man-showpaths() {

    : """Print paths of matching man pages

        Usage: man-showpaths <name>
    """

    [[ $# -eq 0  || $1 == @(-h|--help) ]] &&
        { docsh -TD; return; }

    man -aw "$@"
}
