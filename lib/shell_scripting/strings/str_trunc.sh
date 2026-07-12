: """Shorten a string, substituting '...'.

    Usage: str_trunc [opts] <n> <str>

        n : maximum character length allowed
      str : string to shorten (e.g. path, directory name)

    Options

      -m : truncate in the middle (default)
      -s : truncate at the start
      -e : truncate at the end

    Example

      str_trunc 12 the_path_to_shorten
"""

str_trunc() {

    [[ $# -lt 2  || $1 == @(-h|--help) ]] \
        && { docsh -TD; return; }

	local sloc=m

    local flag OPTARG OPTIND=1
    while getopts "mse" flag
    do
        case $flag in
            ( m ) sloc=m ;;
            ( s ) sloc=s ;;
            ( e ) sloc=e ;;
            ( * ) return 2 ;;
        esac
    done
    shift $(( OPTIND-1 ))

    [[ $# -eq 2 ]] ||
        return 5

    local -i n=$1
    local pstr=$2

    if (( ${#pstr} <= n ))
    then
        printf '%s\n' "$pstr"

    else
        # int char lengths trimmed from start and end
        local a b

        # trim $pstr to $n chars
        case $sloc in
            ( m )
                a=$(( (n - 3)/2 ))

                # handle odd/even case
                if (( (n % 2) == 0 ))
                then
                    b=$(( -1*(a + 1) ))
                else
                    b=$(( -1*a ))
                fi
            ;;
            ( s )
                a=0
                b=$(( -1*(n - 3) ))
            ;;
            ( e )
                a=$(( n - 3 ))
                b=${#pstr}
            ;;
        esac

        printf '%s\n' "${pstr::$a}...${pstr:($b)}"
    fi
}
