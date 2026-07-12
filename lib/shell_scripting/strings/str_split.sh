: """Split string into array elements

    Usage: str_split [-d delim] <array-name> [string] ...

    The elements of the indicated array are defined by splitting the supplied
    string. By default, and when delim is the empty string, the string is split into
    individual characters. If no string is supplied on the command line, STDIN is
    used.

    Options

      -a       : append to array instead of clearing it
      -d delim : split string at each instance of 'delim'
      -q       : suppress warning when non-empty array is cleared

    Examples

      str_split str_elems 'each_char_is_an_elem'
      str_split -d '/' path_elems 'path/to/split'

    See Also: str_to_words, str_join_with
"""

str_split() {

    [[ $# -eq 0  || $1 == @(-h|--help) ]] \
        && { docsh -TD; return; }

    # defaults
    local _v=1 _d='' _a

    local flag OPTARG OPTIND=1
    while getopts ':ad:q' flag
    do
        case $flag in
            ( a ) _a=1 ;;
            ( d ) _d=$OPTARG ;;
            ( q ) (( _v-- )) ;;
            ( \? ) err_msg 2 "unknown option: '-$OPTARG'"; return ;;
            ( : )  err_msg 2 "missing argument for -$OPTARG"; return ;;
        esac
    done
    shift $(( OPTIND-1 ))

    # nameref to the array variable
    local -n _ss_arr=$1 \
        || return
    shift

    # read stdin if necessary
    # - don't be tempted to use $( < /dev/stdin ),
    #   as [noted](https://unix.stackexchange.com/a/716439/85414)
    [[ $# -eq 0 ]] &&
        set -- "$( cat )"

    # split string(s) into temp array
    local s _tmp_arr=()
    for s in "$@"
    do
        if [[ -z $_d ]]
        then
            # Split string into individual characters
            local i
            for (( i=0; i<${#s}; i++ ))
            do
                _tmp_arr+=( "${s:i:1}" )
            done

        elif [[ -n $( command -v mapfile ) ]]
        then
            # Use the mapfile builtin (AKA readarray in newer Bash)
            mapfile -td "$_d" _tmp_arr < \
                <( printf '%s' "$s" )

        else
            # Use read in classic Bash
            local elem
            while IFS='' read -rd "$_d" elem
            do
                _tmp_arr+=( "$elem" )
            done < \
                <( [[ "${s:(-1)}" == "$_d" ]] && printf '%s' "$s" || printf "%s$_d" "$s" )
        fi
    done
    shift $#

    # replace or append to array
    if [[ -v _a ]]
    then
        _ss_arr+=( "${_tmp_arr[@]}" )

    else
        # clear the array
        (( _v > 0 )) && {
            # - this check is better than ${#_ss_arr[@]} and [[ -n ${_ss_arr[*]} ]]
            [[ -v '_ss_arr[*]' ]] \
                && err_msg w "clearing non-empty array '${!_ss_arr}'"
        }
        _ss_arr=( "${_tmp_arr[@]}" )
    fi
}
