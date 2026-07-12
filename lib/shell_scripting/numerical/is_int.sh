is_int () {

    [[ $# -eq 0  || $1 == @(-h|--help) ]] && {

        : """Check for valid integer

        Usage: is_int [options] <string> ...

        Return true (0) if all arguments are integers, false (1) for anything else,
        including the null-string.

        Options

        -p : positive integers only
        -z : non-negative integers only

        Examples

          # check for valid non-neg int
          is_int -z \"\$var\" \
            || echo \"var should be non-neg int\"
        """
        docsh -TD
        return
    }

    local _p _z
    local flag OPTARG OPTIND=1
    while getopts ":pz" flag
    do
        case $flag in
            ( p )
                _p=1 ;;
            ( z )
                _z=1 ;;
            ( \? )
                # could be e.g. '-123'
                OPTIND=$(( OPTIND-1 ))
                break ;;
        esac
    done
    shift $(( OPTIND-1 ))

    # remaining args are strings to test
    local -i rs
    (( $# > 0 )) \
        && rs=0 \
        || rs=1

    # local s=$1
    # shift
    local s
    for s in "$@"
    do
        # in Bash, for pos/neg int, could do:
        #   [[ ${s#[-+]} == +([0123456789]) ]]
        # or use some regex in AWK...
        #   anyway

        # discard valid sign character
        if [[ -v _p  || -v _z ]]
        then
            # pos or non-neg only
            s=${s#[+]}
        else
            # pos/neg
            s=${s#[-+]}
        fi

        # examine remaining chars
        case $s in
            ( *[!0-9]* | '' )
                rs=1
                break
            ;;
            ( * )
                # integer
                # - check for invalid 0, otherwise, we're OK
                if [[ -v _p ]] && (( s == 0 ))
                then
                    rs=1
                    break
                fi
            ;;
        esac
    done

    return $rs
}
