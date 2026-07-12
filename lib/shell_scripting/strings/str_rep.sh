: """Print repetitions of a character or string

    Usage: str_rep <str> [n]

    Print n repetitions of str, followed by a newline (default n = 2).

    Examples

      - Dashes for a table:

        str-rep - 6
        #------

      - Spaces for indentation:

        str-rep ' ' 4
        # (four spaces)
"""

str_rep() {

    [[ $# -eq 0  || $1 == @(-h|--help) ]] \
        && { docsh -TD; return; }

    # args
    local s n
    s=${1?}
    if [[ -v 2 ]]
    then
        n=$2
        shift
    else
        n=2
    fi
    shift

    (( n >= 0 )) \
        || { err_msg 2 "non-negative integer required, got '$n'"; return; }

    # for loop is safer than 'while (( n-- ))', in case of n=null
    # - NB, invalid values (e.g. strings) resolve to 0
    local i
    for (( i=0 ; i<n ; i++ ))
    do
        printf '%s' "$s"
    done

    # add newline if anything was printed
    (( i == 0 )) \
        || printf '\n'

    # another way, tried to get it all in one print statement, but couldn't
    # - output the required no. of words, but use '.0s' to print them as 0-length
    # - would be good if you could use brace expansion with a variable
    # printf "$s"'%.0s' $( for (( i=0 ; i<n ; i++ )); do printf '. '; done ); printf '\n'
}
