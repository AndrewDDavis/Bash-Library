mk444() {
    # alias for discoverability
    touch-444 "$@"
}

touch-444() {

    : """Create a file and give it world-readable permissions

        Usage: touch-444 [-f] <file-name ...>

        Options

          -f : perform chmod, even if the file exists
    """

    # option parsing
    local _f

    local flag OPTARG OPTIND=1
    while getopts ':fh' flag
    do
        case $flag in
            ( f ) _f=1 ;;
            ( h ) docsh -TD; return ;;
            ( \? ) err_msg 2 "unknown option: '-$OPTARG'"; return ;;
            ( : )  err_msg 2 "missing argument for -$OPTARG"; return ;;
        esac
    done
    shift $(( OPTIND-1 ))


    # main loop
    local fn

    for fn in "$@"
    do
        if [[ -e "$fn"  && -z ${_f-} ]]
        then
            err_msg 6 "file exists: $fn"
            return

        elif [[ ! -L "$fn"  && ! -e "$fn" ]]
        then
            # create file
            : > "$fn"
        fi

        chmod a+r "$fn" \
            || return
    done
}
