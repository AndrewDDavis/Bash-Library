: """Test for pattern match using Bash regex comparison

    Usage

        rematch 'pattern' 'string'
        rematch 'pattern' <<< test-string
        rematch 'pattern' < /path/to/text/file

    The \`rematch\` function compares a string against a regular expression. If no
    string is provided on the command line, it is read from STDIN. The pattern uses
    POSIX extended regular expression syntax, as in 'grep -E'.

    This function is meant to replace simple calls to grep. Since Bash's [[ operator is
    used rather than calling an external program, the execution time is much less
    (see note 1 below). Using this function in scripts can also be more convenient
    than calling grep: the results are added directly to variables, which saves the need
    to handle printed output, e.g. with null line terminators.

    Use caution when calling this function with a pattern that matches word boundaries.
    This can produce extra matches -- see note 3 below.

    Rematch returns true (status code 0) when a match occurs, 1 for no match, or > 1 for
    an error.

    Variables produced by rematch:

      REMATCHES
      : This is the main array variable populated by rematch. It contains the text
        portions matched by the pattern and each sub-expression (if any). When no
        matches occur, REMATCHES is declared but empty.

        REMATCHES is analagous to the BASH_REMATCH array variable produced by Bash regex
        comparisons. Refer to the bash manpage for detailed background. Briefly,
        BASH_REMATCH[0] contains the text matched by the pattern, and further
        BASH_REMATCH elements contain the matches to any sub-expressions of the pattern,
        defined by '(...)'.

        While the Bash results are limited to only one comparison, REMATCHES is the
        concatenation of the BASH_REMATCH arrays from all matches. E.g., for a pattern
        with 2 sub-expressions, like '(L)(.)', that matches 4 times within the text,
        REMATCHES would have 12 elements. There would be 4 for each of the overall
        matches (at positions 0, 3, 6, and 9), 4 for each match to the first sub-
        expression (at positions 1, 4, 7, and 10), and 4 for each match to the second
        sub-expression (at positions 2, 5, 8, and 11).

      REMATCH_N
      : This variable contains a count of the number of matches. The number of elements
        of REMATCHES is equal to REMATCH_N multiplied by the number of pattern sub-
        expressions.

      REMATCH_LINES
      : This variable is only defined when rematch is called with the -l option (see
        below). It is populated with matching lines.

    Options

      -l
      : Match within lines, rather than as a free-flowing string. In this context,
        '-p' prints lines rather than only matching portions, and '^' and '$' in the
        pattern match the start and end of lines, rather than the start and end of
        the whole string. The REMATCHES variable still contains matching strings
        and sub-expressions, but REMATCH_LINES is also defined, as described above.

      -p
      : Print matched string segments, or lines if using '-l'.

      -q
      : Only return a true or false status and set the value of REMATCH_N to 1 or 0.
        Don't test for multiple matches, don't print anything (overrides -p), and don't
        populate the REMATCHES or REMATCH_LINES arrays.

        As a side effect, BASH_REMATCH will contain the matched text and sub-expressions
        when using -q. BASH_REMATCH is usually empty after running rematch.

    Compared to GNU grep

      - To mimic a call to 'grep -E', use 'rematch -lp'. This causes rematch to operate
        line-by-line and print matching lines.

      - When rematch is called without the -l option, the behaviour is similar to using
        'grep -Eo'. Only the matching portions of the input text are added to the
        REMATCHES array, or printed when using -p.

      - A count of the number of matches is available from REMATCH_N. However, calling
        'grep -c' outputs a count of matching lines, rather than total matches,
        even when used with '-o'. To obtain this value, call 'rematch -l' and use the
        number of elements in REMATCH_LINES: \${#REMATCH_LINES[*]}.

    Notes

     1. The execution time to match a pattern against a string with 'rematch -q' was
        ~0.10 ms. A non-matching 'rematch -p' was similar, but a matching call took
        ~0.15 ms. By comparison, GNU grep took ~1.4 ms, and ugrep took ~3.8 ms to
        perform the same match (about 10 and 20 times longer, respectively). Notably,
        for simple comparisons, directly running [[ ... =~ ... ]] took only ~0.008 ms.

     2. A null-matching pattern, such as '' or 'a*', always matches. However, it
        produces only 1 match, consisting of the null string. This differs from
        grep, which reprints the entire input. Null-matching sub-expressions work
        similarly. E.g., '(a*)(b*)' produces three null elements in BASH_REMATCH
        and REMATCHES, and REMATCH_N=1, regardless of the input text.

     3. Rematch relies on a shell pattern match of the matched text to search for
        multiple pattern matches in a string. This can fail when the pattern contains
        elements that match an empty string, as in the anchor characters ^ and \$, or
        the special symbols that match word boundaries: \\<, \\>, \\b, and \\B. For such
        patterns, the true/false result of the pattern matching is accurate, but extra
        matches may be reported.

        Rematch treats patterns starting with ^ or ending with \$ as special cases, and
        ensures that they only match once. For other patterns, consider matching the
        leading and trailing parts in your pattern, and using subexpressions to extract
        what you need. E.g. changing the pattern '^.' to '^(.).*' would cause it to work
        as expected, producing REMATCH_N=1 and storing the initial character at
        REMATCHES[1].
"""

rematch() {

    [[ $# -eq 0  || $1 == @(-h|--help) ]] \
        && { docsh -TD; return; }

    # cleanup routine and func definitions
    trap '
        return
    ' ERR

    trap '
        unset -f _parse_args _match_lines \
            _match_string _print_matches
        trap - err return
    ' RETURN

    _parse_args() {

        # option parsing
        local flag OPTARG OPTIND=1
        while getopts ':lpq' flag
        do
            case $flag in
                ( l ) _l=1 ;;
                ( p ) _p=1 ;;
                ( q ) _q=1 ;;
                ( : )  err_msg 2 "missing argument for $OPTARG"; return ;;
                ( \? ) err_msg 3 "unknown option: '$OPTARG'"; return ;;
            esac
        done
        shift $(( OPTIND-1 ))

        # positional arg is pattern
        (( $# > 0 )) \
            || { err_msg 3 "missing pattern argument"; return; }

        (( $# < 3 )) \
            || { err_msg 4 "too many arguments: ${*@Q}"; return; }

        ptn=$1

        # identify anchored patterns
        [[ $ptn == *'$'  || $ptn == '^'* ]] \
            && _ancptn=1

        # note other patterns that match other empty strings, as they
        # can throw off the code that checks for multiple matches
        [[ $ptn == *@('\<'|'\>'|'\b'|'\B'|?'^'|'$'?)* ]] \
            && err_msg w "patterns with special symbols to match empty strings can produce extra matches"

        if (( $# > 1 ))
        then
            txt=$2
        else
            txt=$( < /dev/stdin )
        fi
    }

    _match_lines() {

        # line-by-line matching
        # - read txt lines into REPLY, noting that <<< appends a newline
        while IFS= read -r
        do
            # test for one or more matches within the line
            _match_string "$REPLY" \
                && REMATCH_LINES+=( "$REPLY" )

        done <<< "$txt"

        # return true/false
        (( REMATCH_N ))
    }

    _match_string() {

        # test for one or more matches within the string
        local str=$1

        while [[ $str =~ $ptn ]]
        do
            (( ++REMATCH_N ))
            REMATCHES+=( "${BASH_REMATCH[@]}" )

            # discard the matched part, then check for more matches
            str=${str#*"${BASH_REMATCH[0]}"}

            [[ -v _ancptn ]] && break
        done

        # return true/false
        # - if string and $1 are no longer the same, a match occurred
        #   (allows calling this func from _match_lines)
        [[ $str != "$1" ]]
    }

    _print_matches() {

        if [[ -v _p  && ! -v _q  && REMATCH_N -gt 0 ]]
        then
            # print matching segments or lines
            if [[ -v _l ]]
            then
                printf '%s\n' "${REMATCH_LINES[@]}"
            else
                local i n step
                n=${#REMATCHES[*]}
                step=$(( n / REMATCH_N )) \
                    || return

                # NB, building an array and calling printf once took ~7 us *longer*
                for (( i=0; i<n; i=i+step ))
                do
                    printf '%s\n' "${REMATCHES[i]}"
                done
            fi
        fi
    }

    # variable defaults
    unset REMATCHES REMATCH_N REMATCH_LINES
    declare -ag REMATCHES=()
    declare -ig REMATCH_N=0
    local _l _p _q _ancptn
    local txt ptn

    _parse_args "$@"
    shift $#

    if [[ -v _q ]]
    then
        # simple binary test
        [[ $txt =~ $ptn ]] \
            && REMATCH_N=1

    elif [[ '' =~ $ptn ]]
    then
        # null-matching pattern
        # - e.g. (a*)(b*): BASH_REMATCH=([0]="" [1]="" [2]="")
        REMATCHES=( "${BASH_REMATCH[@]}" )
        REMATCH_N=1

    elif [[ -v _l ]]
    then
        declare -ag REMATCH_LINES=()
        _match_lines "$txt"

    else
        _match_string "$txt"
    fi

    _print_matches

    # return true/false for match
    (( REMATCH_N ))
}

# Notes on optimizing execution time
#
# - putting docstrings within the function took the execution time from ~170 us to ~290
#   us, amazingly. Now that docsh handles doc-strings in the source file, this is no
#   longer an issue.
# - the return trap, which unsets functions and resets itself, accounts for ~ 25 us of
#   the runtime, whereas populating the array of subfunctions accounts for another 10 us.
# - reading the function definitions themselves accounts for ~ 20 us.
# - the docsh test on $# | -h accounts for only a few us.
# - The getopts call is also only a few us; the whole _parse_args function takes only ~
#   20 us.
# - trying to juggle the function definitions so that rematch -q can skip reading the
#   unneeded functions did save a bit of time, ~3 us per function skipped, but probably
#   isn't worth it, due to how strange the code looks. Pre-declaring functions using
#   declare -f func actually added a few us to the execution time.
