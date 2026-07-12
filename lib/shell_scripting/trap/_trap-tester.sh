# TODO: finish testing

_trap-tester() {

    : """Test the functionality of Bash function traps

        This function is intended to troubleshoot and explore how commands and
        variables behave when used in a function trap. Here are the results
        so far:

                    | interactive | ddd() int. |   . ./dotted | bash ./execed
        ------------|-------------|------------|--------------|---------------
        LINENO      |         629 |          2 |            3 |            3
        BASH_LINENO |          () |    [0]=640 |      [0]=642 |        [0]=0
        BASH_SOURCE |          () |   [0]=main | [0]=./dotted | [0]=./execed
        $0          |       -bash |      -bash |        -bash |     ./execed
        FUNCNAME    |   # unbound |    [0]=ddd |    # unbound |    # unbound
        caller      |    # $? = 1 |   640 NULL |     642 NULL |       0 NULL
        caller 0    |    # $? = 1 |   # $? = 1 |     # $? = 1 |     # $? = 1
        caller 1    |    # $? = 1 |   # $? = 1 |     # $? = 1 |     # $? = 1
        ( exit 13 ) |
    """

    # avoid printing the trap for interactive completion functions
    # e.g. echo $SO<Tab>
    # - would be nice, but some still print; 'set +o errtrace' silences it
    # - '[[ -t 1 ]]' makes sure STDOUT is open on a terminal.

    trap -- '
        [[ -t 1  &&  -v FUNCNAME[0] ]] && {
            echo "ERR trap from ${FUNCNAME[0]}()" >&2
            { printf '%s' "caller 1: """; caller 1; } >&2
            return
        }
    ' ERR
}
