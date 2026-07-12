# dependencies
import_func is_set_array is_idx_array seqi array_pop \
    || return

array_shift() {

    : """Remove initial array element(s) and decrement later indices

    Usage: array_shift <array-name> [number]

    The number is interpreted as the number of initial array indices to remove, so that
    e.g. 2 will cause the array elements at indices 0 and 1 to be deleted. If one of
    the elements to be removed does not exist, a warning is printed. If no number is
    provided, 1 is used. After the elements are deleted, the later indices are
    decremented accordingly, while preserving any existing gaps.

    To remove array elements without modifying the index, or for associative arrays,
    use the unset built-in. To reindex an array and remove any gaps, use array_reindex.

    Examples

      abc=( a b c d e f )

      # remove the 1st and 3rd elements
      array_shift abc 3

      declare -p abcs
      # declare -a abc=([0]=\"d\" [1]=\"e\" [2]=\"f\")
    """

    [[ $# -eq 0  || $1 == @(-h|--help) ]] &&
        { docsh -TD; return; }

    # nameref to array
    local -n __ash_arrnm__=$1  || return
    shift

    # Require non-empty indexed array
    is_set_array __ash_arrnm__  && is_idx_array __ash_arrnm__ \
        || { err_msg 3 "non-empty array required, got '${!__ash_arrnm__}'"; return; }


    # number of elems to remove
    local n=1
    (( $# == 0 )) \
        || { n=$1; shift; }

    (( $# == 0 )) \
        || { err_msg 4 "too many arguments"; return; }

    # shift of 0 is a no-op
    (( n > 0 )) \
        || return 0

    # last array index
    local m
    m=$( argmax "${!__ash_arrnm__[@]}" )

    (( (n-1) <= m )) \
        || { err_msg 5 "number ($n) too large for max array index ($m)"; return; }

    # generate and unset indices, and decrement later values
    # - k tracks the number of elements that were removed
    local i k=0
    for (( i=0; i<=m; i++ ))
    do
        if (( i < n ))
        then
            if [[ -v __ash_arrnm__[i] ]]
            then
                unset '__ash_arrnm__[i]'
                (( ++k ))
            else
                err_msg w "${!__ash_arrnm__}[$i] does not exist"
            fi

        elif (( k == 0 ))
        then
            # no elements were removed
            break

        elif [[ -v __ash_arrnm__[i] ]]
        then
            # decrement index of later elements
            __ash_arrnm__[i-k]=${__ash_arrnm__[i]}
            unset '__ash_arrnm__[i]'
        fi
    done
}
