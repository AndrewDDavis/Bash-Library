# This file contains assertion test functions for shell variables. See also
# arrayvar_tests.sh, which contains tests that are specific to array variables.

# Testing notes:
#
# - A variable is "set" if it has been assigned any value, including NUL. Variables may
#   be declared and given attributes, but still be considered "unset". E.g., after
#   declaring an integer variable with 'declare -i i', or a local variable with
#   'local abc', the variables are still unset.
#
#   However, the attributes of such a variable may be queried using ${abc@a}, or by
#   parsing the output of ${abc@A} or 'declare -p abc'.
#
# - When a variable is a nameref, ${abc[*]@A} prints the attributes of the underlying
#   variable, whereas 'declare -p abc' prints the nameref declaration. To print the
#   attributes of the underlying variable using declare, use 'declare -p "${!abc}"'.
#
#   NB, running 1000 iterations of 'declare -p i' and 'echo ${i@A}' both take ~ 10 ms.

is_mt_var() {

    : """Return true for a scalar or array variable that has been declared, but without
        any value set, not even NUL.

        These could be declared using e.g.:
          declare -i i  # integer variable
          local abc     # in a function
          abc=()        # empty array
    """

    [[ $( declare -p "${1:?variable name required}" 2>/dev/null ) == 'declare -'*  \
        && ! -v "$1" ]]

    # local d=$( declare -p "$1" 2>/dev/null )
    # [[ $d == 'declare '*  && $d != *=* ]]
}

is_set_var() {

    : """Return true for a scalar or array variable with any value set, including NUL"

    [[ -v ${1:?variable name required}[*] ]]

    # could also use:
    #   ( set +u; (( ${#arr[*]} > 0 )) )
}

is_nn_var() {

    : """Return true for a scalar or array variable with any non-null value"

    local -n __avt_arrnm__=${1:?variable name required}

    # NB, the simpler [[ -n ${var[*]} ]] test is usually adequate.
    # But it fails for an edge case in which an array with multiple elements, all of
    # which are NUL, would give a true result. The reason is that the nulls would be
    # joined by the first element of IFS.
    # So, you could use a subshell and temporarily set IFS, or otherwise capture it:
    #    ( IFS=''; test "${__avt_arrnm__[*]}"; )
    # A loop can also be used to test elements individually, and this took ~ 20 ms for
    # 1000 iterations, versus ~ 900 ms for the subshell. The '-' is needed in param
    # to ensure test is run with a null arg for unset vars.
    local e
    for e in "${__avt_arrnm__[@]-}"
    do
        test "$e" && break
    done
}

is_scalar() {

    : """Return true for scalar variable, whether set or not"

    [[ $( declare -p "$1" 2>/dev/null ) == 'declare -'*([! aA])' '* ]]
}

is_set_scalar() {

    : """Return true for a scalar variable with any value set, including NUL"

    local -n __avt_varnm__=${1:?variable name required}

    [[ -v __avt_varnm__[*]  && ${__avt_varnm__@a} != *[aA]* ]]
}

is_nn_scalar() {

    : """Return true for a scalar variable with a non-null value"

    local -n __avt_varnm__=${1:?variable name required}

    [[ -n ${__avt_varnm__[*]}  && ${__avt_varnm__@a} != *[aA]* ]]
}
