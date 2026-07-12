: """Determine number of hops to a host

    Usage: ping-hops [-t n] [options] host

    This function uses ping with successively lower TTL values to determine the number
    of hops required to reach a host.

    Other than option '-t <n>', which sets the start value of TTL (default 24), any
    further arguments are passed to ping.
"""

ping-hops() {

    [[ $# -eq 0  || $1 == @(-h|--help) ]] &&
        { docsh -TD; return; }

    trap '
        unset -f _ptest
        trap - return
    ' RETURN

    # args and defaults
    local -i ttl=24

    local flag OPTARG OPTIND=1
    while getopts ':t:' flag
    do
        case $flag in
            ( t ) ttl=$OPTARG ;;
            ( \? )
                # option for ping
                (( OPTIND-- ))
                break
                ;;
            ( : )  err_msg 2 "missing argument for -$OPTARG"; return ;;
        esac
    done
    shift $(( OPTIND-1 ))

    [[ $# -gt 0 ]] ||
        return 3

    local ping_cmd
    ping_cmd=$( builtin type -P ping ) \
        || return 4

    # ensure iputils ping
    [[ $( "$ping_cmd" -V ) == *iputils* ]] ||
        return 5

    # check for missing cap_net_raw
    local priv_elev
    "$ping_cmd" -c 1 -i '0.5' &> /dev/null \
        || {
        printf >&2 '%s\n' "ping-hops: ping may require sudo for cap_net_raw"
        sudo true
        priv_elev=1
    }

    # define ping args other than ttl and host
    local host pargs
    host=${!#}
    pargs=( -c 3 -i '0.5' "$@" )
    shift $#

    _ptest() {
        printf >&2 '%s\r' "Testing ttl=${ttl}...   "
        [[ $ttl -gt 0 ]] || return
        "${priv_elev:+sudo}" "$ping_cmd" -t $ttl "${pargs[@]}" > /dev/null
    }

    printf >&2 '%s\n' "Starting ping-test at ttl=$ttl..."

    # loop with decreasing ttls until failure
    while _ptest
    do
        (( ttl -= 2 ))
    done

    # fine-adjustment: +1 or +2 to success
    (( ++ttl ))
    _ptest $ttl \
        || (( ++ttl ))

    printf >&2 '%s\n' "Host $host is estimated to be $ttl hops away."
}
