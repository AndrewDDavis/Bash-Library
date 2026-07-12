mtdirx() {

    : """Test for an empty directory and use expressive return codes

    Usage: mtdirx [-P] <path>

    This function evaluates the specified path and returns an expressive status code.
    In typical shell operation, a return status of 0 represents success, and greater
    values represent failure.

    Return codes

      0  : empty directory
      1  : non-empty directory
      2  : not a directory
      3  : path not found
      99 : missing path argument

    If the path is a symlink, mtdirx normally follows it to evaluate the file it
    points to. To cause mtdirx to return with status 2 for symlinks, use the
    -P option.

    Since this function uses the built-in \`test\` command rather than \`find\`, it
    does not rely on the user having read and execute permissions for the path.
    """
    [[ $# -eq 0  || $1 == @(-h|--help) ]] &&
        { docsh -TD; return; }

    # -P option
    local _P
    [[ $# -gt 1  && $1 == -P ]] &&
        { _P=1; shift; }

    [[ $# -eq 1 ]] ||
        return 99

    # path
    local _fn=$1
    shift

    if [[ -n ${_P-}  && -L $_fn ]]
    then
        # symlink, and we're not dereferencing
        return 2

    elif [[ -d $_fn ]]
    then
        if [[ -s $_fn ]]
        then
            # non-empty directory
            return 1
        else
            # empty directory
            return 0
        fi

    elif [[ -e $_fn ]]
    then
        # not a directory
        return 2

    else
        # path not found
        return 3
    fi
}
