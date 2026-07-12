_print_args() {

    : """Print arguments provided to the function.

        Usage: _print_args ...

        This function prints its options and positional parameters in a compact but
        readable format. It is intended for troubleshooting shell scripts during
        development. If PA_COMPACT is not null, a compact form is used.
    """

    [[ ${1-} == @(-h|--help) ]] \
        && { docsh -TD; return; }

    if (( $# == 0 ))
    then
        builtin printf >&2 '%s\n' "# (empty args list)"

    elif [[ -v PA_COMPACT ]]
    then
        # match array index to pos'n params
        # shellcheck disable=SC2034
        local args=( "${@:0}" )
        unset 'args[0]'

        # filter declare -p output for readability
        local decp_filt='
            s/declare -a args=(/  /
            s/)$//
        '

        builtin declare -p args \
            | command sed "$decp_filt"

    else
        local i
        for (( i=1; i<=$#; i++ ))
        do
            builtin printf '%3s:%s\n' \
                $i \
                "${!i@Q}"
        done
    fi
}
