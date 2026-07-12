sudo-userpath() {

    : """Run sudo command, keeping the user's PATH

        Usage: sudop <command>

        All arguments are passed through to sudo, after setting PATH to the user's
        PATH variable.
    """

    [[ $# -eq 0  || $1 == @(-h|--help) ]] &&
        { docsh -TD; return; }

    sudo PATH="$PATH" "$@"
}
