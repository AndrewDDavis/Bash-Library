# dependencies (implied)
# - NB, longopts should not be called from docsh or err_msg, or there would be a never-
#   ending loop
#import_func docsh err_msg
#   || return

: """Handle --long-opts and --key=value command line arguments

    Usage

        longopts <var-name>
        longopts <optstring> <var-name> [\"\$@\"]

    This function aids argument parsing of long options in shell scripts and
    functions. By adding simple call to this function within a typical 'while
    getopts ...' argument parsing loop, both long and short options can be handled
    by the same case statement.

    The 'var-name' argument refers to the same flag variable as in the \`getopts\`
    command call. Pass the name, e.g. 'flag' or 'OPT', not the value.

    The string '-:' must be added to the optstring of the \`getopts\` command call.
    Retain any short option flags in the optstring, which are processed by getopts
    in the usual way.

    If the optstring argument is supplied, as in the second command form above,
    it is used to check the option flag received. Longopts checks that the
    optstring list includes the flag, and that required arguments were provided.
    If the positional arguments are supplied to longopts, or BASH_ARGV is set,
    they will be used to obtain a missing argument.

    The optstring format is a space-separated list of long option flags. Flags
    that require an argument should be annotated with a trailing colon (':'), just
    as with the getopts optstring. E.g., the optstring 'abc def: ghi' indicates
    that the --def flag requires an argument, but neither --abc nor --ghi do. The
    error reporting also mimics getopts; silent error reporting is indicated by
    the optstring starting with ':', or setting OPTERR=0. In that case, an
    unrecognized long option is left in OPTARG, and the flag becomes '?'.

    Notes

    - Recall that getopts assigns the current option flag to the var-name
      variable, and assigns its argument to the OPTARG variable, if applicable.

    - The '-:' string causes getopts to process long options by setting the flag
      variable to '-' and putting the remainder of the flag string in OPTARG. It
      is an error if the flag variable is '-', but OPTARG is empty.

      If var-name is not '-' when longopts is called, it silently returns
      with status code 0 (true). This allows argument parsing for short options
      to proceed as usual, typically with a case statement.

    - When the command-line argument was of the form '--key=value', longopts
      sets the flag variable to 'key' and OPTARG to 'value'. For an argument like
      '--long', the flag variable becomes 'long', and OPTARG is unset.

    Examples

     1. Allow the flag '--aaa' as a synonym for '-a', and '--bbb=arg' for '-b arg'.
        NB, '--bbb arg' will also work, as long as you use the full form of the
        longopts call, including the optstring and the positional parameters.

        local flag OPTARG OPTIND=1
        while getopts ':ab:-:' flag       # <- add '-:' to optstring
        do
            longopts flag                 # <- call longopts before the case statement
            # or
            longopts ':aaa bbb:' flag \"\$@\"

            case \$flag in
                ( a | aaa ) _a=1  ;;          # <- long flags added to cases
                ( b | bbb ) _b=\$OPTARG  ;;

                ( : )  err_msg 2 \"missing argument for -\$OPTARG\"; return ;;
                ( \\? ) err_msg 3 \"unknown option: '-\$OPTARG'\"; return ;;

                # ^^^ above is adequate if optstring arg was provided to longopts
                # vvv below is needed if not

                ( * ) err_msg 4 \"unexpected op: '\$flag', '\${OPTARG-}'\"; return  ;;
            esac
        done
"""

longopts() {

    [[ $# -eq 0  || $1 == @(-h|--help) ]] \
        && { docsh -TD; return; }

    # top priority is to read the FLAG var, and return quickly if not a long opt
    local optstr
    (( $# > 1 )) \
        && { optstr=$1; shift; }

    # - using safe var-name to avoid name collision
    local -n __sl_Flag__=$1
    shift

    if [[ $__sl_Flag__ != '-' ]]
    then
        return 0

    elif [[ -z ${OPTARG-} ]]
    then
        err_msg 4 "empty OPTARG"
        return
    fi

    # mimic the way getopts sets FLAG and OPTARG for short options
    if [[ $OPTARG == *=* ]]
    then
        # was a --key=val argument
        # - shell subs avoid external calls to 'cut'
        __sl_Flag__=${OPTARG%%=*}
        OPTARG=${OPTARG#*=}

    else
        # was a simple --flag argument
        __sl_Flag__=$OPTARG
        unset OPTARG
        declare -g OPTARG
    fi

    if [[ -v optstr ]]
    then
        # optstring provided: validate flags and required args

        # check for silent error reporting
        local _silerr
        [[ ${OPTERR-} == 0 ]] \
            && _silerr=1

        [[ $optstr == :* ]] && {
            _silerr=1
            optstr=${optstr:1}
        }

        # convert optstring to array
        # - e.g. optstr=([0]="abc" [1]="def:" [2]="ghi")
        # - split on spaces, newlines, tabs
        local optstr_arr=()
        read -ra optstr_arr -d '' < \
            <( printf '%s\0' "$optstr" )

        # match flag against optstring
        local opt_flag matched
        for opt_flag in "${optstr_arr[@]}"
        do
            [[ ${opt_flag%:} == "$__sl_Flag__" ]] \
                && { matched=1; break; }
        done

        if [[ ! -v matched ]]
        then
            # unrecognized flag
            # - mimic getopts err reporting
            if [[ -v _silerr ]]
            then
                OPTARG=$__sl_Flag__
                __sl_Flag__='?'

            else
                printf >&2 '%s\n' "longopts: illegal option -- $__sl_Flag__"
                __sl_Flag__='?'
                unset OPTARG
            fi

        elif [[ $opt_flag == *: \
            && ! -v OPTARG ]]
        then
            # arg req'd but not defined by --key=value style arg
            if (( $# ))
            then
                # get OPTARG from command-line args
                # - this works because getopts would have advanced OPTIND
                if [[ -v $OPTIND ]]
                then
                    OPTARG=${!OPTIND}
                    (( OPTIND++ ))
                fi

            else
                # if 'shopt -s extdebug' was on when the calling script was initiated,
                # then BASH_ARGV may have the OPTARG
                if [[ -v BASH_ARGV[*] ]]
                then
                    local -i a b n i
                    a=${BASH_ARGC[0]}    # e.g. 2 args for this func
                    b=${BASH_ARGC[1]}    # e.g. 4 args for the calling func
                    n=${#BASH_ARGV[@]}   # e.g. 6

                    # for the above e.g., arg 3 of the calling func is available at BASH_ARGV[2]
                    # 0 1 2 3 4 5
                    if (( b >= OPTIND ))
                    then
                        i=$(( n - 1 - a - (b - OPTIND) ))
                        OPTARG=${BASH_ARGV[i]}
                        (( OPTIND++ ))
                    fi
                fi
            fi

            # if OPTARG wasn't found above, mimic getopts err reporting
            if [[ ! -v OPTARG ]]
            then
                if [[ -v _silerr ]]
                then
                    OPTARG=$__sl_Flag__
                    __sl_Flag__=':'

                else
                    printf >&2 '%s\n' "longopts: option requires an argument -- $__sl_Flag__"
                    __sl_Flag__='?'
                    unset OPTARG
                fi
            fi
        fi
    fi
}
