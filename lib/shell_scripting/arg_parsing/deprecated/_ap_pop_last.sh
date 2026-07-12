# this function is deprecated

_ap_pop_last() {

    [[ $# -eq 0 || $1 == @(-h|--help) ]] && {

        docsh -TD """Assign last positional arg to variable

        I couldn't get this function to work without requiring complicated syntax on
        the receiving side, which defeats the purpose. Instead, just use this code in
        your function:

          var=\${!#}
          set -- \"\${@:1:\$#-1}\"

        Usage (above is recommended instead)

          _ap_pop_last <var-name> <arr-name>
          set -- \"\${arr-name[@]}\"

        Assigns last post'l arg to var-name, then assigns remaining post'l args to
        arr-name. Assign the post'l args to arr-name, as above, to remove the last arg,
        if desired.
        """
        return 0
    }

    local -n var=$1     # name-ref to the variable that will be assigned to
    local -na arr=$2    # name-ref to the array that will be assigned to

    var=${@:(-1)}
    arr=${@:1:$#-1}

    # originally tried to find a form of printf or e.g. ${arr@Q}, couldn't find one
    #printf '%q\n' "$@"
}
