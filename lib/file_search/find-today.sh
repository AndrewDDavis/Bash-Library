find-today() {

    : """Find items that were modified today

        Usage: find-today [path] [search-terms]

        All arguments are passed to the 'find' command, then arguments are added to limit
        the search results to files modified today.
    """

    [[ $# -eq 0  || $1 == @(-h|--help) ]] &&
        { docsh -TD; return; }

    command find "$@" -daystart -mtime -1
}
