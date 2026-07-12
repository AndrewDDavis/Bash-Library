mtdir() {

    : """Test for an empty directory

    Usage: mtdir [-P] <path>

    The \`find\` command is used to examine the file path, and mtdir returns with
    status code 0 (success) if the path represents an empty directory. mtdir returns
    with status 1 if the path is a non-empty directory, if it is not a directory, if
    the path does not exist, or if there are insufficient permissions to check whether
    a directory is empty. In the latter two cases, an error is printed by \`find\`.

    If the path is a symlink, mtdir normally follows it to evaluate the file it points
    to. To cause symlinks to produce a failed test, use the -P option.
    """
    [[ $# -eq 0 || $1 == @(-h|--help) ]] &&
        { docsh -TD; return; }

    local fd_out

    fd_out=$( command find -L "$@" -maxdepth 0 -type d -empty ) \
        && [[ -n $fd_out ]]
}
