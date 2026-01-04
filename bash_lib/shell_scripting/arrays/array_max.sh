# dependencies
import_func is_set_array \
    || return

array_max() {

    [[ $# -eq 0  ||  $1 == @(-h|--help) ]] && {

        : """Print maximum value from array

        Usage: array_max <array name>

        Return status is 0 for success, 2 for more than 1 arg, 3 if the name is not a
        non-empty array, and 4 if an array element is not an integer.
        """
        docsh -TD
        return
    }

    # nameref to array
    local -n __am_arrnm__=$1 \
        || return
    shift

    [[ $# -eq 0 ]] ||
        return 2

    # Require non-empty array
    is_set_array __am_arrnm__ \
        || { err_msg 3 "non-empty array required, got '${!__am_arrnm__}'"; return; }


    trap '
        unset -f _elem_isint
        trap - return
    ' RETURN

    _elem_isint() {

        is_int "${__am_arrnm__[$1]}" ||
            { err_msg 4 "${!__am_arrnm__}[$1] not an int: '${__am_arrnm__[$1]}'"; return; }
    }


    # loop over array to find the max
    local i _max idcs

    # indices of referenced array
    idcs=( "${!__am_arrnm__[@]}" )

    i=${idcs[0]}
    _elem_isint "$i" \
        || return

    _max=${__am_arrnm__[$i]}

    for i in "${idcs[@]:1}"
    do
        _elem_isint "$i" \
            || return

        (( ${__am_arrnm__[$i]} <= _max )) \
            || _max=${__am_arrnm__[$i]}
    done

    printf '%s\n' "$_max"
}
