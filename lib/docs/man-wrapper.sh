: """Limit man page width on wide terminals

    Usage: man-wrapper [--mw=<n>] [man-options] name ...

    This function is a transparent wrapper for man that adds two features:

      - It limits the width of the displayed page.
      - It adds the --nj option to the man command. This disables full-width
        justification of the page (ragged-right).

    The page width is limited by dynamically setting the MANWIDTH environment
    variable, depending on the present terminal width. The variable is set to
    95% of the terminal width if it's less than the limit value. This is
    better than a blanket value, as a terminal width lower than e.g. the
    default value of 80 causes awkward wrapping of the displayed page.

    Option:

      --mw=<n> : width limit in chars (default 88)

    All other arguments are passed to man as usual. To view the help page for man,
    use '/bin/man -h' or 'command man -h'.
"""

man() {

    [[ $# -eq 0  || $1 == @(-h|--help) ]] &&
        { docsh -DT; return; }

    # default
    local _manwidth=88

    local flag OPTARG OPTIND=1
    while getopts ':-:' flag
    do
        # long option: split key=value so that flag=key and OPTARG=value (may be empty)
        if [[ $flag == '-' ]]
        then
            flag=${OPTARG%%=*}
            [[ $OPTARG == *=* ]] \
                && OPTARG=${OPTARG#*=} \
                || OPTARG=''

            # flag=$( cut -d= -f1 <<< "$OPTARG" )
            # OPTARG=$( cut -d= -sf2 <<< "$OPTARG" )
        fi

        case $flag in
            ( mw )
                _manwidth=$OPTARG
                shift
            ;;
            ( * )
                break
            ;;
        esac
    done


    # terminal width may limit the width to less than the max
    local tw
    tw=${COLUMNS:-$( tput cols )}
    tw=$( awk -v "n=$tw" 'BEGIN { print int(n*0.95) }' )

    (( tw >= _manwidth )) ||
        _manwidth=$tw


    # array of environment variables to set
    # - set MANWIDTH if needed
    local -a evars

    [[ -n ${MANWIDTH-} ]] ||
        evars+=( "MANWIDTH=$_manwidth" )


    # disable justification
    # - quoting is OK: don't add escaped quotes, they will become part of the value
    # - could escape the $, but then you would need to eval the export line
    evars+=( "MANOPT=${MANOPT:+"$MANOPT "}--nj" )

    # call man in subshell
    (
        # - or could do ${evars[@]:+export "${evars[@]}"}
        [[ -n ${evars[*]} ]] &&
            export "${evars[@]}"

        command man "$@"
    )
}
