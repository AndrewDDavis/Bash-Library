mkcd() {

    : """Create directory and cd to it in one step

        Usage: mkcd <path>

        The path argument represents a directory, which will be created if it does
        not exist. Then the CWD of the shell will be changed to that dirctory.
    """

    [[ $# -ne 1  || $1 == @(-h|--help) ]] &&
        { docsh -TD; return; }

    command mkdir -pv "$1"
    builtin cd "$1"
}
