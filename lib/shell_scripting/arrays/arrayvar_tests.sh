# This file augments var_tests.sh with assertion tests that are specific to array
# variables.

# The best way to validate an array variable depends on the details of the application.
# It may depend on e.g. whether an empty array is considered valid, whether a scalar
# variable should be considered an array with one element, and possibly whether you
# know the status of 'set -u'.

# Depending on the application, it may be necessary to use two of following tests:
#
# 1. Test the number of array elements, e.g.:
#
#    n=${#arr[*]} && (( n > 0 )) || echo FALSE
#
#       variable type | set -u | result
#    -----------------|--------|------------
#     non-empty array |     on | true, n > 0
#                     |    off | true, n > 0
#          set scalar |     on | false, unbound variable
#                     |    off | true, n=1
#         empty array |     on | false, n=0
#                     |    off | false, n=0
#      unset variable |     on | false, unbound variable
#                     |    off | false, n=0
#
# 2. Test whether a variable is set (see note below), e.g.:
#
#    [[ -v arr[*] ]] || echo FALSE
#
#       variable type | set -u | result
#    -----------------|--------|------------
#     non-empty array |     on | true
#                     |    off | true
#          set scalar |     on | true
#                     |    off | true
#         empty array |     on | false
#                     |    off | false
#      unset variable |     on | false
#                     |    off | false
#
# 3. Testing a variable's attributes can be done is several ways, e.g.:
#
#    [[ ${arr@a} == *[aA]* ]] || echo FALSE
#
#    The table below shows sample outputs for testing array attributes, with empty
#    outputs shown as NUL. These results apply to indexed arrays. Entries indicating
#    (error) produce an unbound variable error message and terminate the process
#    immediately when querying attributes. For 'declare -p', a "not found" error is
#    produced for unbound variables, and execution continues.
#
#       variable type | set -u | ${arr@a} | ${arr@A} | ${arr[*]@a} | ${arr[*]@A} | declare -p
#    -----------------|--------|----------|----------|-------------|-------------|------------
#     non-empty array |     on |        a | -a arr=o |     a a ... | -a arr=(... | -a arr=(...
#                     |    off |        a | -a arr=o |     a a ... | -a arr=(... | -a arr=(...
#          set scalar |     on |      NUL |  abc=... |         NUL |     abc=... |  -- abc=...
#                     |    off |      NUL |  abc=... |         NUL |     abc=... |  -- abc=...
#         empty array |     on |  (error) |  (error) |         NUL |   -a arr=() |   -a arr=()
#                     |    off |        a |   -a arr |         NUL |   -a arr=() |   -a arr=()
#      unset variable |        |          |          |             |             |
#    (declare -a arr) |     on |  (error) |  (error) |           a |      -a arr |      -a arr
#                     |    off |        a |   -a arr |           a |      -a arr |      -a arr
#         (unset arr) |     on |  (error) |  (error) |         NUL |         NUL |     (error)
#                     |    off |      NUL |      NUL |         NUL |         NUL |     (error)

# Testing notes:
#
# - Depending on how you read the help page for the 'declare' built-in command, it may
#   appear that you can test for array attributes using e.g. 'declare -pa NAME' to test
#   whether NAME is an indexed array. This is not the case: per the bash manpage, when
#   -p is used with name arguments, additional options other than -f and -F are ignored.
#
# - A variable is "set" if it has been assigned any value, including NUL. An array
#   variable is considered set if any elements have a value.
#
#   Variables, including arrays, may be declared and given attributes, but still be
#   considered "unset". E.g., after the statement 'declare -a arr', arr is still unset,
#   although its attributes may be queried using ${arr@a}, or by parsing the output of
#   ${arr@A} or 'declare -p arr'.
#
#   Unlike scalar variables, arrays may also be considered "empty" in some cases. This
#   can occur if it is defined using arr=() or if all of its elements are unset. An
#   empty array is also "unset", but querying the number of elements is valid, e.g.
#   n=${#arr[*]} results in n == 0.
#
# - Testing the number of elements (test #1) doesn't distinguish between scalars and
#   arrays when running with 'set +u'.
#
# - Testing whether the variable is "set" (test #2) is consistent regardless of
#   'set -u', and may be understood as testing whether any element of an array is
#   set (i.e. whether any element has any value, even NUL).
#
#   Don't use [[ -v arr ]] for arrays, as that only tests whether arr[0] is set.
#
# - The results of test #3 are surprisingly heterogeneous. The most useful and
#   consistent version is ${arr[*]@A}, which provides the same amount of information as
#   declare -p. The 'set +u' form of ${arr@a} can also be useful, as a simple test of
#   whether or not a variable is an array.
#
#   Note that the ${arr@A} expansion actually tests the first element of a set array,
#   leading to inconsistent results when the first element is unset. OTOH, ${arr[*]@a}
#   actually prints the attributes for each value of a set array.
#
#   When the variable is a nameref, ${arr[*]@A} prints the attributes of the underlying
#   variable, whereas 'declare -p arr' prints the nameref declaration. To print the
#   attributes of the underlying variable using declare, use 'declare -p "${!arr}"'.

is_array() {

    : """Return true for array variable, whether set, unset, or empty"

    local -n __avt_arrnm__=${1:?variable name required}

    [[ ${__avt_arrnm__[*]@A} == 'declare -'*([! ])[aA]*([! ])' '* ]]

    # could also use:
    #   ( set +u; [[ ${arr@a} == *[aA]* ]] )
    # or
    #   local rgx='^declare -[^ ]*[aA][^ ]* '
    #   [[ ${arr[*]@A} =~ $rgx ]]
}

is_mt_array() {

    : """Return true for an empty array variable (no elements, not even a NUL)

        These could be defined using, e.g.:
          arr=()
        or
          declare -a arr
    """

    [[ $( declare -p "${1:?variable name required}" 2>/dev/null ) \
        == 'declare -'*([! ])[aA]*([! ])" ${1}"?('=()') ]]
}

is_set_array() {

    : """Return true for an array variable with any value set, including NUL"

    local -n __avt_arrnm__=${1:?variable name required}

    [[ -v __avt_arrnm__[*]  && ${__avt_arrnm__@a} == *[aA]* ]]
}

is_nn_array() {

    : """Return true for an array variable with at least 1 non-null element"

    local -n __avt_arrnm__=${1:?variable name required}

    # [[ -n ${__avt_arrnm__[*]}  && ${__avt_arrnm__@a} == *[aA]* ]]
    # work around edge case of array with multiple NUL values; see is_nn_var
    local e
    for e in "${__avt_arrnm__[@]-}"
    do
        test "$e" && break
    done \
        && [[ ${__avt_arrnm__@a} == *[aA]* ]]
}

is_idx_array() {

    : """Return true for indexed array variable, whether empty or not"

    local -n __avt_arrnm__=${1:?variable name required}

    [[ ${__avt_arrnm__[*]@A} == 'declare -'*([! ])a*([! ])' '* ]]
}

is_asoc_array() {

    : """Return true for associative array variable, whether empty or not"

    local -n __avt_arrnm__=${1:?variable name required}

    [[ ${__avt_arrnm__[*]@A} == 'declare -'*([! ])A*([! ])' '* ]]
}
