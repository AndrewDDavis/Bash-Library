# TODO:
# - address difference btw getopts and getopts_long for -a-- arg
# - address difference btw getopts and getopts_long for -' ' arg with space in opt-string
# - old note: currently testing with the grep-files function, switch to unit test

# relevant getopts behaviour (TODO: merge into notes):
# - argument '--':
#   gopts exits with status=1, sets OPT to '?', unsets OPTARG, and advances OPTIND
#   this behaviour doesn't change with silent error reporting (i.e. ':...')
# - argument '-.':
#   treated like any other valid single-letter option flag

_getopts-tester() {

    [[ $# -eq 0 ]] || [[ $# -eq 1 && $1 == -h ]] && {

        : """Examine and test the getopts builtin compared to the getopts_long function

        Example usage:

          opt_string=':ab:cd-:'
          opt_parser=( builtin getopts -- )  # or getopts_long
          getopts_tester -a -b foo -cd --flag --key=val abc


        Results table of getopts behaviour:

          opt-string       args   i   OPT   OPTARG OPTIND  RS Comment
          -------------- ------ --- ------ ------- ------ --- ------------------
          'ab:'              -a   1      a (unset)     +1   0
          ':ab:'             -a   1      a (unset)     +1   0
          'ab:'             -aa   1      a (unset)     +0   0 Sub-OPTIND tracked internally
          'ab:'             -aa   2      a (unset)     +1   0
          'ab:'             -a1   1      a (unset)     +0   0
          'ab:'             -a1   2      ? (unset)     +1   0 msg: illegal option -- 1
          ':ab:'            -a1   2      ?      1      +1   0

          'ab:'             -b1   1      b      1      +1   0
          'ab:'            -b 1   1      b      1      +2   0
          'ab:'              -b   1      ? (unset)     +1   0 msg: option requires an argument -- b
          ':ab:'             -b   1      :      b      +1   0

          'ab:'      -ab1 -- -c   1      a (unset)     +0   0
          'ab:'      -ab1 -- -c   2      b      1      +1   0 '--' terminates loop, increments OPTIND
          ':ab:'     -ab1 -- -c   2      b      1      +1   0 same with silent error reporting

          'ab:'              -d   1      ? (unset)     +1   0 msg: illegal option -- d
          ':ab:'             -d   1      ?      d      +1   0

          ^^^ getopts_long consistent up to here

          'a'              -a--   1      a (unset)     +0   0
          'a'              -a--   2      ? (unset)     +0   0 msg: illegal option -- -
          'a'              -a--   3      ? (unset)     +1   0 msg: illegal option -- -
          ':a'             -a--   2      ?      -      +0   0
          ':a'             -a--   3      ?      -      +1   0
          'a-:'            -a--   2      -      -      +1   0
          ':a-:'           -a--   2      -      -      +1   0

          'a b:'           -' '   1  (sp.) (unset)     +1   0 space is a valid flag, if in opt-string

          'ab:-: foo'     --foo   1      -    foo      +1   0 allows for long-opt handling

          getopts_long only vvv

          'a foo'         --foo   1    foo (unset)     +1   0
          'a foo:'    --foo=bar   1    foo    bar      +1   0
          'a foo:'    --foo bar   1    foo    bar      +2   0
          'a foo:'        --foo   1      ? (unset)     +1   0 msg: option requires an argument -- foo
          ':a foo:'       --foo   1      :    foo      +1   0
          'a foo:'        --bar   1      ? (unset)     +1   0 msg: illegal option -- bar
          ':a foo:'       --bar   1      ? foobar      +1   0
          'a b foo'       --foo   1    foo (unset)     +1   0
        """
        docsh -TD
        return
    }

    _print_args "$@"

    # default parser
    [[ -n ${opt_parser:-} ]] ||
        local opt_parser=( builtin getopts -- )

    printf 'opt_parser: %s\n' "$( printf '%s ' "${opt_parser[@]}" )"

    # default opt_string
    [[ -n ${opt_string:-} ]] ||
        local opt_string=':ab:cd-:'

    printf '%s\n' "opt_string: '$opt_string'"

    # print a table of values
    printf '\n%2s %2s %10s %10s %10s %10s %10s\n' \
        i j '!j' '!(j+1)' OPT OPTARG OPTIND

    local OPT OPTARG OPTIND=1 i=1 j=1 k rs

    while "${opt_parser[@]}" "$opt_string" OPT "$@"  ||  { rs=$?; ( exit $rs ); }
    do
        k=$(( j + 1 ))

        printf '%2d %2d %10s %10s %10s %10s %10s\n' \
            $i $j "${!j-(unset)}" "${!k-(unset)}" "$OPT" "${OPTARG-(unset)}" "$OPTIND"

        j=$OPTIND
        (( i++ ))
    done

    printf '\n%s\n' "return status: ${rs}"
    printf '%s\n' "shifting $(( OPTIND-1 ))"
    shift $(( OPTIND-1 ))

    _print_args "$@"
}
