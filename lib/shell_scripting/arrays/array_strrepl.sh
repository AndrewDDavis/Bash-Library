# dependencies
import_func is_set_array \
    || return

: """Replace array element matching string with one or more new elements

    Usage: array_strrepl <array-name> <string> [elem1 [elem2 ...]]

    The first array element that exactly matches the string is replaced by elem1,
    then any further elements are added to follow. If no new elements are provided,
    the matching element is deleted. Indices following the replaced element
    are adjusted as explained by array_irepl().
"""

array_strrepl() {

    [[ $# -eq 0  ||  $1 == @(-h|--help) ]] &&
        { docsh -TD; return; }

    # array name and pattern, then remaining args are new elements
    local -n __asr_arrnm__=$1   || return
    local s=$2                  || return
    shift 2

    # Require non-empty array
    # - refer to arrayvar_tests.sh for details on testing variable properties
    #   (it's actually pretty complicated)
    is_set_array __asr_arrnm__ \
        || { err_msg 3 "non-empty array required, got '${!__asr_arrnm__}'"; return; }


    # rely on other array functions where possible
    local k rs
    k=$( array_match -nF -- "${!__asr_arrnm__}" "$s" ) || {
        # allow status = 1 for no match
        rs=$?
        [[ $rs == 1 ]] && return 1
        err_msg $rs "error in array_match"
        return
    }


    if [[ ${__asr_arrnm__@a} == *A* ]]
    then
        # associative array
        if [[ $# -eq 0 ]]
        then
            unset "__asr_arrnm__[$k]"

        elif [[ $# -eq 1 ]]
        then
            __asr_arrnm__["$k"]=$1

        else
            err_msg 5 "associative arrays can only take one element"
            return
        fi

    else
        # pass the original array name, to save a layer of abstraction
        array_irepl "${!__asr_arrnm__}" "$k" "$@"
    fi
}
