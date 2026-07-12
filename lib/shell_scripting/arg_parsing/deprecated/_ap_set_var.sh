# this function is deprecated

_ap_set_var() {

    [[ $# -eq 0 || $1 == @(-h|--help) ]] && {

        docsh -TD """Get required arg from lumped string or next arg.

        Usage: _ap_set_var <var-name> \"\${1:-}\" || shift

        Hint: check out _arg_def instead

        """
        return 0
    }

    echo "try _arg_def instead"
    return

    local -n var=$1     # name-ref to the variable to set

    # get required arg from lump or next arg
    if [[ -n ${lump:-} ]]
    then
        var=$lump
        unset lump
        return 0
    elif [[ -n $2 ]]
    then
        var=$2
        return 1
    else
        err_msg 3 "missing required arg to set '$1' for '$opt'"
        return 3
    fi
}
