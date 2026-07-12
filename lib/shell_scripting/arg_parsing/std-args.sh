# docsh docs
: """Group arguments into arrays, setting aside some special ones

    Usage: std-args OA PA SS LS [-s sf lf [-s ...]] [--] \"\$@\"

    This function populates the OA and PA arrays with the option and positional
    arguments passed on the command line, which are determined from the SS and LS
    strings. All four positional arguments are required, but SS and LS may be empty:

      OA : Name of array to be populated with option flags and their arguments. The
           array values retain the form and the indices of the command line parameters.
      PA : Name of array to be populated with positional arguments, which retain the
           indices from the command line.
      SS : String of short options that require an argument, e.g. 'abCD'.
      LS : String of long options that require an argument, seperated by spaces,
           e.g. 'file regexp max-count after-context'.

    An array called '_stdopts' is also populated with all option flags and their
    arguments in a standardized form. In particular, blobs of short-option flags are
    individually split, with any argument attached, and long option flags are
    attached to their arguments using '='. The following examples demonstrate the
    four possible option forms in '_stdopts': '-q', '--quiet', '-epattern', and
    '--regex=pattern'. The order of the options is retained from the command line, but
    the indices necessarily change.

    This function is most useful for wrapper functions or scripts, in which you want
    to pass the arguments through to another command in their original form, but
    take note of some arguments of special interest, e.g. the patterns to a
    \`grep\` call.

    Due to the nature of this function, it is recommended to issue the '--' argument
    before passing the command-line arguments to be examined.

    Options

      -s <sf> <lf>
      : Identify an option of special interest. The two string arguments represent
        the short- and long-form option flags. Both arguments are required, but one
        may be empty. This option may be used multiple times.

        Two arrays will be created: 'spec_args' will hold the arguments to special
        flags, and 'spec_idcs' will hold the indices. The format of 'spec_idcs' is
        'i1,i2,i3,...', and the values correspond to the order of the -s flags used
        on the command-line.

        Special option flags should also be included in the SS and LS strings passed
        as positional arguments. If flag-only options are of particular interest, it
        is recommended to test the special '_stdopts' array, e.g. with the
        array_match function.

    Notes

      - This function generally allows options to be written on the command line after
        positional arguments. This follows the behaviour of e.g. rsync and GNU grep, in
        which 'grep -e P file1 -i' matches lines with a lowercase or uppercase 'p' from
        a file called 'file1'. In this case, '-e', 'P', and '-i' would be added to the
        option array, and 'file1' to the positional argument array.

      - This function also honours the '--' argument to terminate option parsing, and
        adds it to the positional argument array. E.g. in grep, 'grep -- file1 -e P'
        would print 'no such file' errors for '-e' and 'P'. Sensible ways to write the
        command include 'grep -e P -- file1' and 'grep -- P file1'. However, '--' may be
        placed anywhere, as long as no options follow it. Thus, 'grep P -- file1' and
        'grep P file1 --' work in the same way.

      - It is generally safe to leave long option flags with *optional* arguments out of
        the LS array, as commonly occurs with '--color[=WHEN]'. In this case, the
        options are already in standard form, so they will be added to _stdopts and the
        OA array as expected.

      - More problematic are hybrid long and short options, as with ugrep's '-%%', and
        multiple optional arguments, as with ugrep's '--and [-e] PAT'.

    Examples

    1. parse options, without specifying special cases

        set -- -a AAA -dbBBB --abc this --bar ghi that
        std-args opt_args pos_args 'ab' 'foo bar' -- \"\$@\"

        # inspect results
        declare -p opt_args pos_args _stdopts
        # opt_args=([1]=\"-a\" [2]=\"AAA\" [3]=\"-dbBBB\" [4]=\"--abc\" [6]=\"--bar\" [7]=\"ghi\")
        # pos_args=([5]=\"this\" [8]=\"that\")
        # _stdopts=([0]=\"-aAAA\" [1]=\"-d\" [2]=\"-bBBB\" [3]=\"--abc\" [4]=\"--bar=ghi\")

    2. parse grep options, as in _parse_grepopts()

        so='efmABCdD'
        lo='max-count label after-context ...'  # refer to _parse_grepopts for full list

        std-args opt_args pos_args \"\$so\" \"\$lo\" \\
            -s 'e' 'regexp'  -s 'f' 'file' -- \"\$@\"

        # inspect results
        declare -p opt_args pos_args _stdopts spec_args spec_idcs
"""

std-args() {

    [[ $# -eq 0  || $1 == @(-h|--help) ]] \
        && { docsh -TD; return; }

    # err trap and clean up
    trap '
        return
    ' ERR

    trap '
        unset -f _parse_sa_args _def_lfpat _handle_longopt _handle_shortopt
        trap - err return
    ' RETURN

    _parse_sa_args() {

        ## Special options and associated vars
        # - NB, robust and simple ways to communicate arg info back to the calling
        #   function are limited. Ideas:
        #    1. Output all flags as separate words, with their OPTARGS if applicable, and let
        #       the calling function sort it out as it sees fit.
        #    2. Add the relevent indices for the spec_args array to spec_idcs, following the
        #       order of the -s options given on the CLI.
        # - std-args does both: the non-local arrays spec_args and spec_idcs hold
        #   the arguments to special flags and their indices, while _stdopts holds all
        #   options and arguments in a standardized form.
        local _args=( '' "$@" )
        local -i i=1
        while [[ ${_args[i]-} == -s ]]
        do
            [[ -v _args[i+1]  && -v _args[i+2] ]] \
                || { err_msg 8 "missing argument to -s (SS and LS both required, but may be empty)"; return; }

            [[ -n ${_args[i+1]}  || -n ${_args[i+2]} ]] \
                || { err_msg 9 "need non-empty argument to -s (SS and LS may not both be empty)"; return; }

            sp_sfa+=( "${_args[i+1]}" )
            sp_lfa+=( "${_args[i+2]}" )
            (( i += 3 ))
        done
        (( n += (i-1) ))

        if [[ -v sp_sfa[*] ]]
        then
            spec_args=()
            spec_idcs=()
        fi

        if [[ ${_args[n+1]-} == '--' ]]
        then
            # -- terminates std-args option parsing
            (( ++n ))
        fi
    }

    _def_lfpat() {

        # convert long flags that require an OPTARG to a pattern string, as in
        # "foo|bar|baz", after word-splitting
        if [[ -z $lfs ]]
        then
            lf_pat=''

        else
            local lf_words
            read -ra lf_words -d '' < \
                <( printf '%s\0' "$lfs" )

            lf_pat=$( str_join_with '|' "${lf_words[@]}" )
        fi
    }

    _handle_longopt() {

        # long option:
        # - long options that don't require an arg can be passed through
        # - long options that require an arg, and are given as --key=value,
        #   can be passed through, but capture any patterns
        # - long options that require an arg, and are given as --key, should
        #   be passed through with the following arg, and note any patterns
        local i
        if [[ ${ext_args[n]#--} == @($lf_pat) ]]
        then
            # long options that require an arg, and are alone
            # - this includes regexp and file (now)
            # - note the arg to --colo[u]r is optional, so it's handled below

            # check for special flags
            for i in "${!sp_sfa[@]}"
            do
                if [[ -n ${sp_lfa[i]}  && ${ext_args[n]#--} == "${sp_lfa[i]}" ]]
                then
                    spec_idcs[i]+=",${#spec_args[@]}"
                    spec_args+=( "${ext_args[n+1]}" )
                    break
                fi
            done

            __opts__[n]=${ext_args[n]}
            __opts__[n+1]=${ext_args[n+1]}
            _stdopts+=( "${ext_args[n]}=${ext_args[n+1]}" )
            (( n += 2 ))

        else
            # other long option flags, like --ignore-case, and args that
            # have both the flag and the arg, like --label=foo

            if [[ ${ext_args[n]} == *=* ]]
            then
                # check for special flags
                for i in "${!sp_sfa[@]}"
                do
                    if [[ -n ${sp_lfa[i]}  && ${ext_args[n]%%=*} == "--${sp_lfa[i]}" ]]
                    then
                        spec_idcs[i]+=",${#spec_args[@]}"
                        spec_args+=( "${ext_args[n]#*=}" )
                        break
                    fi
                done
            fi

            __opts__[n]=${ext_args[n]}
            _stdopts+=( "${ext_args[n]}" )
            (( n++ ))
        fi
    }

    _handle_shortopt() {

        # short option:
        # - short option blobs with only flag options are safe to pass through
        # - short option blobs with OPTARG options in the middle are safe
        #   to pass through, but capture any patterns
        # - short option blobs with OPTARG options at the end should be
        #   passed through with the following arg, and note any patterns

        # match with anchored regex patterns
        # - or match using [[ ... == ... ]] that allows extglob, e.g. +([$sfs])
        # - however [[ ... =~ ... ]] produces BASH_REMATCH array, which is useful
        local i
        if [[ -z $sfs ]]
        then
            # no short flags need args
            __opts__+=( "${ext_args[n]}" )
            (( n++ ))

        elif [[ ${ext_args[n]} =~ ^-([^$sfs]*)([$sfs])$ ]]
        then
            # blobs that need the next arg for the OPTARG, like '-e' or '-ie'
            for i in "${!sp_sfa[@]}"
            do
                # check for special flags
                if [[ ${BASH_REMATCH[2]} == "${sp_sfa[i]}" ]]
                then
                    spec_idcs[i]+=",${#spec_args[@]}"
                    spec_args+=( "${ext_args[n+1]}" )
                    break
                fi
            done

            while [[ -n ${BASH_REMATCH[1]} ]]
            do
                # add the initial flags to _stdopts, individually
                _stdopts+=( "-${BASH_REMATCH[1]:0:1}" )
                BASH_REMATCH[1]=${BASH_REMATCH[1]:1}
            done

            _stdopts+=( "-${BASH_REMATCH[2]}${ext_args[n+1]}" )

            __opts__[n]=${ext_args[n]}
            __opts__[n+1]=${ext_args[n+1]}
            (( n += 2 ))

        else
            # other blobs that don't need args, like '-iq', and blobs that
            # include the OPTARG after the flag, like '-efoo'

            # NB, safe blobs match against [[ ${ext_args[n]} =~ ^-([^$sfs]+)$ ]]
            # - match an inclusive pattern, then test BASH_REMATCH elements
            [[ ${ext_args[n]} =~ ^-([^$sfs]*)(([$sfs]).+)?$ ]]

            while [[ -n ${BASH_REMATCH[1]} ]]
            do
                # add the initial flags to _stdopts, individually
                _stdopts+=( "-${BASH_REMATCH[1]:0:1}" )
                BASH_REMATCH[1]=${BASH_REMATCH[1]:1}
            done

            if [[ -n ${BASH_REMATCH[2]} ]]
            then
                # capture the flag and its OPTARG if special
                local optarg
                optarg=${ext_args[n]#-*"${BASH_REMATCH[3]}"}

                for i in "${!sp_sfa[@]}"
                do
                    if [[ ${BASH_REMATCH[3]} == "${sp_sfa[i]}" ]]
                    then
                        spec_idcs[i]+=",${#spec_args[@]}"
                        spec_args+=( "$optarg" )
                        break
                    fi
                done

                _stdopts+=( "-${BASH_REMATCH[2]}" )
            fi

            __opts__[n]=${ext_args[n]}
            (( n++ ))
        fi
    }

    # name-refs to handle opt and posn arg arrays
    local -n __opts__=${1:?} __pargs__=${2:?}
    __opts__=()
    __pargs__=()

    # non-local _stdopts array is always created
    _stdopts=()

    # short and long option strings for flags that require args
    local sfs=${3:?} lfs=${4:?}
    shift 4

    # handle -s and --
    local -a sp_sfa sp_lfa
    local -i n=0
    _parse_sa_args "$@"
    shift $n

    # create pattern from long flags (LS)
    local lf_pat
    _def_lfpat

    # loop over arguments
    local ext_args=( '' "$@" )
    shift $#

    n=1
    while [[ -v ext_args[n] ]]
    do
        case ${ext_args[n]} in

            ( [!-]* | - )
                # positional arg
                __pargs__[n]=${ext_args[n]}
                (( n++ ))
            ;;

            ( -- )
                # terminate option parsing, all following are positional args
                __pargs__[n]=${ext_args[n]}

                [[ -v ext_args[n+1] ]] \
                    && __pargs__+=( "${ext_args[@]:n+1}" )

                break
            ;;

            ( --* )
                _handle_longopt
            ;;

            ( -* )
                _handle_shortopt
            ;;
        esac
    done

    if [[ -v sp_sfa[*] ]]
    then
        # trim initial ',' from spec_idcs
        local i
        for i in "${!spec_idcs[@]}"
        do
            spec_idcs[i]=${spec_idcs[i]/#,/}
        done
    fi

    # sanity: all external args assigned to either __opts or __pargs?
    n=$(( ${#ext_args[*]} - 1 ))
    (( n == ( ${#__opts__[*]} + ${#__pargs__[*]} ) )) \
        || err_msg 9 "#ext_args=${n}, while #__opts__=${#__opts__[*]} and #__pargs__=${#__pargs__[*]}"
}
