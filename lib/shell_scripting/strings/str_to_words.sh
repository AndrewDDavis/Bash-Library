str_to_words() {

    [[ $# -eq 0 || $1 == @(-h|--help) ]] && {

        : """Split string into words, respecting quoting and escaped whitespace

        Usage: str_to_words [-q] <array-name> [string ...]

        This function splits one or more strings and places the resulting words into an
        array. The splitting follows the shell's rules, as whitespace and newlines
        within the string are preserved when they are quoted or escaped with '\\'. This
        is accomplished safely by using a call to 'xargs'. Refer to the notes below on
        unsafe ways to split strings in the shell.

        If no string is supplied on the command line, STDIN is read. If multiple strings
        are supplied, they are considered together. Thus, multiple arguments may be
        combined into one array element if they are connected by quotes.

        Options

          -q : suppress the warning when the array is not empty.

        Example

          s='multi-line'\$'\\n''string * with \"quoted parts\" and\\ an escape'
          str_to_words ww \"\$s\"
          # now ww=([0]=\"multi-line\" [1]=\"string\" [2]=\"*\" [3]=\"with\"
          #         [4]=\"quoted parts\" [5]=\"and an\" [6]=\"escape\")

        Notes

        Word splitting into an array can be done in several ways. Typcal strategies are
        to naively let the shell split an unquoted variable in the array definition, or
        use \`'eval'\`. However, both of these methods are subject to glob expansions
        and other avenues of code execution performed by the shell, which are often
        unwanted and may be dangerous. Consider running this line in a directory with
        files 'x', 'y', and 'z':

          string='abc def \"g h\" \"*\" * \$(echo pwned)'

        Using str_to_words safely splits the string into words:

          str_to_words arr \"\$string\"

        This keeps 'g' and 'h' together in one word, creates two words of only '*', and
        two words at the end consisting of '\$(echo' and 'pwned)'.

        On the other hand, the following code does not respect quoting within the
        string, and expands glob patterns:

          arr=( \$string )

        This creates separate words '\"g' and 'h\"', and expands '*' so that 'x', 'y',
        and 'z' are array elements.

        Using eval on the quoted string keeps 'g' and 'h' together, but still expands
        the unquoted glob, and even runs the command, so the last array element is just
        'pwned':

          eval arr=( \"\$string\" )

        A safer strategy is to use \`read\` to create the array by splitting according
        to the IFS variable, and quote the string to prevent glob expansions. Printing
        the string with a null terminator also allows multi-line strings to be handled:

          read -ra arr -d '' < <( printf '%s\0' \"\$string\" )

        This works safely in simple cases, but it does not respect quoting within the
        string when word-splitting, so it cannot preserve whitespace within the
        elements. str_to_words offers this feature with a simpler command syntax.
        """
        docsh -TD
        return
    }

    # verbosity
    local _v=1
    [[ $1 == -q ]] &&
        { (( _v-- )); shift; }

    # nameref to the array variable
    local -n _arr=$1 || return
    shift

    # read stdin if necessary
    # - don't be tempted to use $( < /dev/stdin ), as [noted](https://unix.stackexchange.com/a/716439/85414)
    [[ $# -eq 0 ]] &&
        set -- "$( cat )"


    # Clear the array
    [[ $_v -gt 0 ]] && {
        # - check and warn, avoiding unbound variable on ${#_arr[@]}
        [[ -n ${_arr[@]} ]] &&
            { err_msg w "clearing non-empty array '${!_arr}'"; }
    }
    _arr=()


    # Safely populate the array
    # - This uses xargs to (re-)evaluate the string, without calling (eeevil) eval.
    # - And it uses null characters to delimit items, which allows anything to be within
    #   them, as long as they're properly quoted.
    # - Nulling IFS is also necessary to prevent stripping of leading and trailing
    #   whitespace in the fields.
    # - For other alternatives, refer to 'Force Word Splitting in Bash' in my Shell
    #   Scripting notes.

    if [[ -n $( command -v mapfile ) ]]
    then
        # Use the mapfile builtin (AKA readarray in newer Bash)
        mapfile -d '' _arr < \
            <( xargs printf '%s\0' <<< "$@" )

    else
        # Use read in classic Bash
        local item

        while IFS='' read -rd '' item
        do
            _arr+=( "$item" )

        done < \
            <( xargs printf '%s\0' <<< "$@" )
    fi

    # check return status of the process substitution
    local xa_pid=$!
    wait $xa_pid || {
        err_msg $? "error in background process"
        return
    }
}
