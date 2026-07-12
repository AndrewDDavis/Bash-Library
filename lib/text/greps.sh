# deps
import_func alias-resolve array_strrepl \
    || return

egreps() {
    greps -E "$@"
}

: greps """Smart-case matching with grep

    Usage

        greps [opts] <pattern> [file1 or - ...]
        greps [opts] -e <pattern1> ... [file1 or - ...]

    This wrapper function passes almost all of its arguments straight through to the
    local \`grep\` command, and can generally be used as a replacement. It introduces
    \"smart-case\" matching, as seen e.g. in the 'less' pager: the pattern matching is
    case-insensitive for lower-case search patterns, but case-sensitive if the pattern
    includes non-escaped uppercase letters.

    The smart-case functionality can be disabled using the --case-sensitive option. It
    is also disabled if the -i, --ignore-case, or --no-ignore-case options are used.

    For simple pattern-matching without an external call to the grep binary, refer to
    the \`rematch\` function.

    Background: relevant case-sensitivity options across grep tools

      Gnu grep
      : -i (--ignore-case), --no-ignore-case
        Uses -s for --no-messages, nothing on -S, -j, or -J.

      BSD grep
      : -i (--ignore-case)
        Uses -s for --no-messages, -S for follow symlinks, -J for bz2decompress,
        nothing on -j; --no-ignore-case does NOT work.

      ripgrep
      : -i (--ignore-case), -S (--smart-case), -s (--case-sensitive);
        Uses -j for --threads, nothing on -J; --no-ignore-case does NOT work.

      ugrep
      : -i (--ignore-case), --no-ignore-case, -j (--smart-case);
        Uses -s for --no-messages, -S for --dereference-files, and -J for --jobs.
"""

greps() {

    [[ $# -eq 0  || $1 == @(-h|--help) ]] \
        && { docsh -TD; return; }

    # inherit verbosity, if any
    local -I _verb
    [[ -n ${_verb-} ]] \
        || _verb=1

    # trap err and clean up
    trap '
        return
    ' ERR

    trap '
        unset -f _def_gcmd _enact_scase
        trap - err return
    ' RETURN

    _def_gcmd() {

        # use full path to grep, but also keep any defined alias
        local grep_path
        grep_path=$( builtin type -P grep ) \
            || return 9

        alias-resolve grep grep_cmd \
            || grep_cmd=( grep )

        array_strrepl grep_cmd grep "$grep_path"
    }

    _enact_scase() {

        if [[ ${#cl_opts[@]} -gt 0 ]]
        then
            # Check for --case-sensitive, -i, etc. in cl_opts and _stdopts
            local n

            if n=$( array_match -nF cl_opts '--case-sensitive' )
            then
                _i=0
                unset "cl_opts[n]"

            elif array_match _stdopts '-i|--ignore-case|--no-ignore-case'
            then
                _i=0
            fi
        fi

        if (( _i ))
        then
            # enact smart case by checking for uppercase in patterns
            # - if no upper-case letters, then do case-insensitive matching
            # - *[[:upper:]]* is nice and simple, but misses regex elements like \W
            # - Could also do [[ $pat == [[:upper:]]* || $pat == *[!\\][[:upper:]]* ]], but
            #   it doesn't seem to make much difference: time reports both that and the
            #   regex variant below take 0.000s for a short string match.
            local p

            for p in "${cl_pats[@]}"
            do
                [[ $p =~ (^|[^\\])[[:upper:]] ]] && {

                    # non-escaped uppercase found: use case sensitive match
                    _i=0
                    break
                }
            done
        fi

        (( ! _i )) \
            || cl_opts+=( -i )
    }

    # define grep command with full path and any defined alias
    local grep_cmd
    _def_gcmd

    # Parse the arguments as grep would
    # - This is relatively complex, as the grep patterns can come from the first
    #   positional arg, from one ore more -e flags, or from -f. Refer to the
    #   _parse_grepopts function for details.
    # - greps needs the _stdopts array to check for -i, and an array of pattern
    #   arguments to check for uppercase characters.
    local cl_opts cl_args cl_pats _stdopts
    _parse_grepopts cl_opts cl_args cl_pats "$@"

    # Enact smart case: add -i to cl_opts unless uppercase or case options specified
    local -i _i=1
    _enact_scase

    # NB, cl_pats are also included in the argument arrays
    run_vrb "${grep_cmd[@]}" "${cl_opts[@]}" "${cl_args[@]}"
}


: _parse_grepopts """Keep command-line argument blobs intact while identifying pattern arg(s)

    Usage: _parse_grepopts A1 A2 A3 \"\$@\"

    This function uses std-args to parse its arguments in the same way as grep. It
    returns arrays containing the options (A1) and positional arguments (A2), as well as
    an array of patterns (A3). The _stdopts array is also created, which contains all
    options and their arguments in a standardized form (refer to std-args).

    The behaviour of GNU grep is replicated. In particular:

      - If a pattern is provided using -e, --regexp, -f or --file, all positional args
        are treated as filenames. Otherwise, the first positional arg is treated as the
        pattern.
      - Multiple patterns may be provided using -e.
      - The pattern arguments may be given as '-e pat', '-epat', '--regexp=pat', or
        '--regexp pat'.
      - Options may be issued after positional arguments, unless the '--' argument is
        used to terminate option parsing.
"""

_parse_grepopts() {

    # name-refs to handle the arrays
    local -n _optargs=${1:?} _posargs=${2:?} _pats=${3:?}
    shift 3

    _pats=()

    # call std-args with the list of flags that need args, and noting pattern flags
    # - this clears and sets _optargs and _posargs
    local spec_idcs spec_args

    local sf='efmABCdD'
    local lf='regexp file max-count label
              after-context before-context context
              group-separator binary-files devices directories
              exclude exclude-from exclude-dir include'

    std-args _optargs _posargs "$sf" "$lf" \
        -s 'e' 'regexp'  -s 'f' 'file' -- "$@" \
        || return

    # check for patterns or pattern files
    if [[ ${#spec_args[@]} -eq 0 ]]
    then
        # no pattern yet: get it from 1st postnl arg

        # first _posargs index
        local i
        for i in "${!_posargs[@]}"; do break; done

        _pats[0]=${_posargs[i]}
        [[ ${_posargs[i]} == -- ]] \
            && _pats[0]=${_posargs[i+1]}

    else
        local i idcs=() fn lines=()

        if [[ -n ${spec_idcs[0]-} ]]
        then
            # pattern args

            # extract idcs
            # - could also use:
            #   idcs=( ${spec_idcs[0]//,/ } )
            IFS=',' read -ra idcs <<< "${spec_idcs[0]}"

            # note patterns
            for i in "${idcs[@]}"
            do
                _pats+=( "${spec_args[i]}" )
            done
        fi

        if [[ -n ${spec_idcs[1]-} ]]
        then
            # pattern-file args

            IFS=',' read -ra idcs <<< "${spec_idcs[1]}"

            for i in "${idcs[@]}"
            do
                # import patterns from file
                fn=${spec_args[i]}

                # man grep says: the empty file contains zero patterns, and therefore
                # matches nothing.  If FILE is - , read patterns from standard input.
                # - in practice, an empty file provides no patterns, but patterns
                #   provided by other means still match as usual
                [[ $fn == '-' ]] && fn=/dev/stdin

                [[ -r "$fn" ]] &&
                    IFS='' mapfile -t lines < "$fn"

                [[ ${#lines[@]} -eq 0 ]] ||
                    _pats+=( "${lines[@]}" )
            done
        fi
    fi

    [[ ${#_pats[@]} -gt 0 ]] \
        || { err_msg 5 "no pattern"; return; }
}
