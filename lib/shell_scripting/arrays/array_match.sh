# TODO:
# - try to use rematch() (i.e. [[ ... =~ ... ]]) instead of grep, to avoid the external
#   command call

# dependencies
import_func is_array \
    || return

: """Test array elements for match to a pattern

    Usage: array_match [options ...] <array-name> <pattern>

    The elements of the array are tested against the pattern. By default,
    array_match returns silently with a true or false return status. For the
    'array-name' argument, pass the name of an existing array variable, not the
    expanded array.

    By default, the pattern is treated as a POSIX ERE that must match an entire
    array element, rather than a substring. For the pattern syntax, refer to the
    manpages of regex(7), grep, and isalpha.

    Options

    -E : treat pattern as POSIX extended regular expression (ERE)
    -F : treat pattern as a fixed string

    -i : case-insensitive match
    -s : allow substring match within array elements
    -v : invert the logic: test for elements that do not match the pattern

    -c : print only the count of matching elements (overrides -n and -p)
    -n : print the index or key of the first matching array element
    -p : print the value of the first matching array element. If both -n and -p are
         used, the output is in the form 'key:value'.
    -a : with -n or -p, print all elements or keys, not just the first

    The return status is 0 (true) for a match, 1 (false) for no match, or > 1 if an
    error occurs. An empty array always returns 1, but array elements consisting of
    the null string may be matched as usual. It is an error if the named variable
    is not set, or is a scalar variable rather than an array.

    Examples

      arr=('one' 'bananas' 'apples' 'two words')

      # returns true:
      array_match arr bananas

      # returns false:
      array_match arr banana

      # returns true:
      array_match -s arr banana

      # returns true:
      array_match arr 'ban.*'

      # returns false:
      array_match -F arr 'ban.*'

      # prints the first matching element index:
      array_match -n arr 'ban.*'
      # 1

      # prints all matching indices and elements:
      array_match -anp arr '.*n.*'
      # 0:one
      # 1:bananas

      # number of elements with an s
      array_match -sc arr 's'
      # 3
"""

array_match () {

    [[ $# -eq 0  || $1 == @(-h|--help) ]] \
        && { docsh -TD; return; }

    # clean up local funcs
    trap '
        unset -f _grep_run
        trap - return
    ' RETURN

    # defaults and arg-parsing
    local re_type=E \
        _a _i _x=x _v \
        _c _n _p

    local flag OPTARG OPTIND=1
    while getopts "EFaisvcnp" flag
    do
        case $flag in
            ( E | F ) re_type=$flag ;;
            ( a )  _a=1  ;;
            ( i )  _i=i  ;;
            ( s )  _x='' ;;
            ( v )  _v=v  ;;
            ( c )  _c=1  ;;
            ( n )  _n=1  ;;
            ( p )  _p=1  ;;
            ( \? )
                err_msg 2 "illegal option: '$OPTARG'"
                return ;;
        esac
    done
    shift $(( OPTIND-1 ))

    # positional args
    [[ $# -eq 2 ]] \
        || return 2

    # - array nameref and pattern (or string)
    local -n __am_arrnm__=$1    || return
    local ptn=$2                || return
    shift 2

    # Require array variable
    # - refer to arrayvar_tests.sh for variable testing details (it can get complicated)
    is_array __am_arrnm__ \
        || { err_msg 3 "array variable required, got '${!__am_arrnm__}'"; return; }

    # empty array returns 1 (no match), and count of 0
    # - NB, using __...__ vars because a namespace collision can cause real problems here
    local __grep_out__=()
    if [[ -v __am_arrnm__[*] ]]
    then
        # Both matching styles below use grep
        # - NB, I originally tried a form using Bash '[[': [[ "${__am_arrnm__[@]}" =~ $ptn ]].
        #   This was very concise, but not totally precise: an expression combining two
        #   adjascent array values with a space between matches, even though it should not.
        local __grep_cmd__
        __grep_cmd__=( "$( builtin type -P grep )" ) \
            || return

        # grep returns with status 0 for a match, 1 for no match
        # local -i grep_rs=0

        # relevant grep options:
        #   -E : pattern is an ERE
        #   -F : pattern is a fixed string
        #   -i : case-insensitive
        #   -m <n> : stop after finding <n> matches
        #   -n : prefix each output line with the 1-based line number (e.g. '53:...')
        #   -q : quiet (also quits immediately on match, which helps efficiency)
        #   -v : invert match logic
        #   -x : match whole lines
        #   -z : null-terminated lines
        __grep_cmd__+=( -nz "-${re_type}${_i-}${_v-}${_x-}" -e "$ptn" )

        # if not all or count, then only 1 and done
        [[ -v _a  || -v _c ]] \
            || __grep_cmd__+=( -m1 )

        # create array of keys
        # - needed for sparse or associative array
        # - this locks in an order for associative arrays
        # - the index of this array matches the line numbers output by grep
        # - the values are the indices of the input array
        local i __keys__=( '' "${!__am_arrnm__[@]}" )

        # now we can run with -n, and later convert the line number to the array index
        mapfile -d '' __grep_out__ < \
            <( "${__grep_cmd__[@]}" < \
                <( for i in "${__keys__[@]:1}"; do printf '%s\0' "${__am_arrnm__[i]}"; done ) )

        # grep return status
        # - NB, $! expands to PID of most recent background job
        # - grep returns with status 0 for a match, 1 for no match, 2 for error
        wait $! || {
            (( $? < 2 )) \
                || { err_msg 2 "grep error"; return; }
        }
    fi

    # match count
    local c=${#__grep_out__[@]}

    if [[ -v _c ]]
    then
        # print match count
        # - return 1 if c == 0
        printf '%s\n' "$c"
        (( c )); return

    elif (( c == 0 ))
    then
        return 1

    else
        # If we got this far, __grep_out__ has some value e.g.:
        #   __grep_out__=([0]="1:abc" [1]="4:bbb")
        # It will only have one entry, unless -a was used.

        # set key for which info to print
        local k=${_n:-0}${_p:-0}

        [[ $k == 00 ]] \
            && return

        # print result, converting line numbers to array index
        local s
        for s in "${__grep_out__[@]}"
        do
            i=${s%%:*}

            case $k in
                ( 11 ) printf '%s:%s\n' "${__keys__[i]}" "${s#*:}" ;;
                ( 10 ) printf '%s\n' "${__keys__[i]}" ;;
                ( 01 ) printf '%s\n' "${s#*:}" ;;
            esac
        done
    fi
}
