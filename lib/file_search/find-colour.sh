find-colour() {

    : """Colourize find results using ls

    Usage: find-colour [path] [search-terms]

    All arguments are passed to the 'find' command, then the results are passed through
    ls to colourize the results.

    The output isn't exactly the same as the colorization of fd and bfs, since those
    programs selectively color the dir portion of a path.
    """

    [[ $# -eq 0  || $1 == @(-h|--help) ]] &&
        { docsh -TD; return; }

    command find "$@" -exec ls -1pd --color '{}' \;
}
