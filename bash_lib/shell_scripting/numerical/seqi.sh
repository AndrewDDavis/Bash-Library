seqi() {

    : """Print a sequence of integers

        Usage: seqi [first [increment]] last

        This function prints integers from first to last, in steps of increment. If
        first is omitted, it defaults to 1. If increment is omitted, it defaults to 1
        if last is greater than first, otherwise to -1. The increment may not be 0. The
        sequence ends when adding the increment would make a number greater than last 
        (less than last with a negative increment).

        Although seqi works similarly to GNU seq, there are differences:

          - This function only prints integer values, and does not handle floating
            point values at all.

          - If last is less than first, and increment is omitted, the increment is -1.

        In terms of time, seqi operates faster than seq for small numbers of values,
        since seq is an external binary. However, seq is faster above ~100 values.

        Options

        -s <string>
        : separate printed numbers using this format string
          (default: '\n', representing a newline)

        -w
        : equalize width of printed numbers by padding with leading zeroes
    """

    # defaults and options
    local _s='\n' _w

    local flag n OPTARG OPTIND=1
    while getopts ':s:wh' flag
    do
        case $flag in
            ( s ) _s=$OPTARG ;;
            ( w ) _w=1 ;;
            ( h ) docsh -TD; return ;;
            ( \? )
                [[ $OPTARG == [0-9] ]] && {
                    # handle 'first' positional args of -2 or -16, which look like option flags
                    n=$(( OPTIND-1 ))
                    [[ ${!n} == -[0-9] ]] \
                        && (( OPTIND-- ))
                    break
                }
                err_msg 3 "unknown option: '$OPTARG'"
                return
            ;;
            ( : ) err_msg 4 "missing argument for $OPTARG"; return ;;
        esac
    done
    shift $(( OPTIND-1 ))

    # positional args: [first [increment]] last
    local frst incr last
    case $# in
        ( 0 ) docsh -TD; return ;;
        ( 1 ) frst=1;  last=$1 ;;
        ( 2 ) frst=$1; last=$2 ;;
        ( 3 ) frst=$1; incr=$2; last=$3 ;;
        ( * ) err_msg 5 "too many arguments: '$*'"; return ;;
    esac
    shift $#

    # ensure valid incr
    if [[ -z ${incr-} ]]
    then
        incr=1
        (( frst > last )) && incr=-1

    elif (( incr == 0 ))
    then
        err_msg 5 "increment may not be 0"
        return
    fi

    # output format
    local fmt="%d${_s}"
    if [[ -v _w ]]
    then
        # set width format string
        # e.g. printf '%03d\n' 3

        # longest string could be first or last, e.g. -2 vs 3
        # - 'seq -w -2 3' prints -2 -1 00 01 02 03
        local slen=${#frst}
        (( ${#last} > ${#frst} )) \
            && slen=${#last}

        fmt="%0${slen}d${_s}"
    fi

    # define the comparison and integer list
    local comp='i<=last'
    (( incr < 0 )) && comp='i>=last'

    local i is=()
    for (( i=frst; "$comp"; i=i+incr ))
    do
        is+=( "$i" )
    done

    # - generating the whole string in one step sped this up
    #   from ~900 ms for 1000 entries, to ~15 ms
    # - for small numbers of entries, generating the string still takes a large amount
    #   of the total time, whereas the above loop to generate the array takes < 1 ms
    # - above ~ 1000 entries, the above loop takes more time than generating the string
    # - for ~ 5000 entries, the print statement takes about the same time as generating
    #   the string

    if [[ -v is[*] ]]
    then
        # generate formatted string
        # - NB, empty is supplies 0 as number
        local ostr
        ostr=$( printf "$fmt" "${is[@]}" )

        # strip the last separator and print the string with a newline
        printf '%s\n' "${ostr%"$(printf "$_s")"}"
    fi
}
