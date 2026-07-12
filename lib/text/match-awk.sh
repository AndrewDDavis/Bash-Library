# Test for pattern match using awk
#
# Usage: match-awk 'pattern' <<< test-string
#
# This matches the lines of STDIN against a regex pattern in a similar way to
# grep -Eq. However, using awk can have advantages, e.g. expansion of '\n' and
# '\t'. The pattern uses ERE regular expression syntax (refer to man awk).
#
# Options
#
#   -p : print first matching line
#   -a : when used with -p, print all matching lines
#
# Returns 0 (true) for a match, or 1 for no match.

match-awk() {

    # defaults and option parsing
    local _a=0 _p=0

    local flag OPTARG OPTIND=1
    while getopts ':aph' flag
    do
        case $flag in
            ( a ) _a=1 ;;
            ( p ) _p=1 ;;
            ( h ) docsh -TD; return ;;
            ( \? ) err_msg 2 "unknown option: '-$OPTARG'"; return ;;
            ( : )  err_msg 2 "missing argument for -$OPTARG"; return ;;
        esac
    done
    shift $(( OPTIND-1 ))

    # positional arg is pattern
    (( $# > 0 )) ||
        { err_msg 3 "missing pattern argument"; return; }

    (( $# == 1 )) ||
        { err_msg 4 "too many arguments: ${*@Q}"; return; }

    local ptn=$1
    shift


    # awk command
    local awk_cmd filt

    awk_cmd=( "$( builtin type -P awk )" ) \
        || return 9

    awk_cmd+=( -v "ptn=$ptn" )
    awk_cmd+=( -v "pr=$_p" )
    awk_cmd+=( -v "all=$_a" )

    # awk script
    filt='
        BEGIN { yn=0; }
        $0 ~ ptn {
            yn=1
            if ( pr ) print $0
            if ( ! all ) exit 0
        }
        END { if ( ! yn ) exit 1; }
    '

    "${awk_cmd[@]}" "$filt"
}
