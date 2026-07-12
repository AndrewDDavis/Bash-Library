_getopts-demo() {

    : """Demonstrate and test simple getopts functionality

        Error reporting:

        - Silent error reporting is enabled in this function.

          With default error reporting, getopts prints error messages but still
          returns with status 0, so the loop merrily carries on. Another important
          difference when using default error reporting is that OPT becomes '?',
          rather than ':', for a missing argument.
    """

	[[ ${1-} == @(-h|--help) ]] &&
    	{ docsh -TD; return; }

    printf '%s\n\n' "args: ${*@Q}"
    local n=1 i=1

    local flag OPTARG OPTIND=1
    while getopts ':n:' flag
    do
        printf '%s\n' "getopts iter $i:"
        declare -p flag OPTARG OPTIND 2>/dev/null

        case $flag in
            ( n )
                n=$OPTARG

                # ensure positive int
                [ "$n" -gt 0 ] || return 2
            ;;
            ( '?' )
                # Unknown option
                # - for a wrapper function, preserve it and break
                (( OPTIND-- ))
                break
                # - otherwise, perhaps error message
                echo >&2 "Invalid option: ${OPTARG@Q}"
                return 1
            ;;
            ( ':' )
                # Missing arg
                echo >&2 "Missing argument for ${OPTARG@Q}"
                return 2
            ;;
        esac

        (( i++ ))
        printf '\n'
    done
    shift $(( OPTIND-1 ))

    printf '%s\n' "n: ${n@Q}"
    echo "args: ${*@Q}"
}
