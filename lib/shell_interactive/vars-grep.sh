# deps (optional)
import_func greps

: """Print variables that match a pattern

    Usage: vars-grep [-a] [grep-opts] [pattern]

    This function prints variable names from the current shell environment that match the
    pattern provided on the command line. If no pattern is provided, all variable names
    are printed.

    If the greps function is available, it is used to provide smart-case matching (case-
    insensitive unless the pattern contains uppercase letters). The -E flag is added by
    default, so that patterns are treated as POSIX ERE regex expressions.

    The 'declare' built-in command is used to print all variables, before filtering
    them with grep or greps. Other than the -a option, all arguments are passed
    through to grep.

    Options

      -a
      : Match against variable values, rather than only names and attributes.

    Notes

      - For name-only searches, 'ls-vars | grep -i zip' will print a list of
        variable names that contain 'zip' (case-insensitive). OTOH,
        'vars-grep -a zip' will match against the variable names and values.

    Examples

      # match variables with OPT in the name
      vars-grep OPT

      # match variables with zip (or Zip, ZIP, ...) in the name or value
      vars-grep -a zip

      # match all arrays (even read-only, exported, etc.)
      vars-grep '^declare -[^ ]*a[^ ]* '
"""

vars-grep() {

    [[ $# -gt 0  && $1 == @(-h|--help) ]] \
        && { docsh -TD; return; }

    # args
    # - use double-underscore var names to prevent collisions with the shell environment
    local __all
    [[ ${1-} == -a ]] \
        && { __all=1; shift; }

    # no filtering if no args
    [[ $# -eq 0 ]] \
        && set -- '^'

    local __grep_cmd __sed_cmd
    if [[ -n $( command -v greps ) ]]
    then
        __grep_cmd=( greps -E )
    else
        __grep_cmd=( "$( builtin type -P grep )" -E ) \
            || return 9
    fi

    # remaining args are pattern and options for grep
    __grep_cmd+=( "$@" )
    shift $#

    __sed_cmd=( "$( builtin type -P sed )" ) \
        || return 9
    __sed_cmd+=( 's/=.*//' )

    trap '
        unset -f _dec_filt
        trap - return
    ' RETURN

    _dec_filt() {

        # print variables, but filter this func's local vars
        builtin declare -p \
            | command grep -Ev ' (__all|__grep_cmd|__sed_cmd)(=|$)'
    }

    local rs
    if [[ -v __all ]]
    then
        _dec_filt \
            | "${__grep_cmd[@]}" \
            | "${__sed_cmd[@]}"

        rs=${PIPESTATUS[1]}

    else
        _dec_filt \
            | "${__sed_cmd[@]}" \
            | "${__grep_cmd[@]}"

        rs=${PIPESTATUS[2]}
    fi

    return "$rs"
}
