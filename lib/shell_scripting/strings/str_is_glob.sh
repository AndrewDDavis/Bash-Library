str_is_glob() {

    : """Check whether a string contains globbing metacharacters

        Usage: str_is_glob <string> ...

        Specifically, this function checks for the presence of '?', '*', '[', or ']'
        in any of the passed strings. If any of those characters occur, the function
        returns with status code 0 (true). Otherwise it returns 1 (false).

        It does not account for quoting or escaping of the metacharacters.
    """

    local s rs=1

    for s in "$@"
    do
        # check for glob wildcard characters '?', '*', or '[' and ']'
        if [[ $s == *[][?*]* ]]
        then
            rs=0
            break
        fi
    done

    return $rs
}
