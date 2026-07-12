str_join_with() {

    [[ $# -eq 0  || $1 == @(-h|--help) ]] && {

        : """Join all arguments into a string using a delimiter

        Usage: str_join_with <delim> <elem1> <elem2> ...

        A string is printed to stdout consisting of the arguments joined by the
        delimiter, which can be a single character or a multi-character string.

        This function returns success unless less than 2 arguments are supplied.

        When joining elements of an array by a single character, it's tempting to use
        a simple shell command line like:

          IFS=':' str=\${arr[*]}

        However, because that line comprises only variable assignments, without any
        command, IFS is modified for all subsequent lines in the shell. This is likely
        to have surprising and undesirable consequences. An alternative would be a to
        use 'printf' in a subshell:

          str=\$( IFS=':'; printf '%s\n' \"\${arr[*]}\" )

        Here, the semicolon after the IFS assignment is required, which makes
        remembering the command line a bit fragile. One could also use a simple loop,
        but that takes a few more lines, so it's a good idea to use this function even
        in simple cases.
        """
        docsh -TD
        return
    }

    [[ $# -gt 1 ]] ||
        return 2

    local delim=$1
    local elem1=$2
    shift 2

    # pattern substitution: # matches the start of the string
    printf '%s' "$elem1" "${@/#/${delim}}" \
        && printf '\n'
}
