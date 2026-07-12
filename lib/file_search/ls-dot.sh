# deps
import_func alias-resolve \
    || return

ll-dot() {
    ls-dot --use-alias=ll "$@"
}

: """List only dot-files in a directory

    Usage: ls-dot [--use-alias=...] [ls-options] [dir ...]

    The glob patternd '.[^.]*' and '..?*' are used to match only dotfiles. If no
    'dir' is specified, the current directory is used.

    All options are passed to ls. The '-d' option is included by default, so that
    the contents of dot-directories are not shown. To pass the name of a directory
    that begins with -, use an argument of '--' to signal the end of options.

    Also set aliases, like:
      alias ll-dot='ls-dot --use-alias=ll'
"""

ls-dot() {

    [[ $# -gt 0  &&  $1 == @(-h|--help) ]] \
        && { docsh -TD; return; }

    ## Check for call by alias (e.g. ls-dot --use-alias=ll)
    local ls_cmd=ls lscmd_words

    if [[ ${1:-} == --use-alias=* ]]
    then
        ls_cmd=${1#--use-alias=}
        shift
    fi

    ## Resolve aliases like 'll', 'lw', etc., and honour any alias for 'ls' defined in
    #  the execution environment (e.g. 'ls --color')
    alias-resolve "$ls_cmd" lscmd_words \
        || lscmd_words=( "$ls_cmd" )

    array_strrepl lscmd_words ls "$( builtin type -P ls )"


    ## Identify options for ls and add them to the cmd-line
    lscmd_words+=( '-d' )

    while [[ ${1:-} == -* ]]
    do
        if [[ $1 == '--' ]]
        then
            shift
            break

        elif [[ $1 != --*  &&  $1 == -*@(I|T|w) ]]
        then
            # ls options that take an arg: -I, -T, -w

            lscmd_words+=( "$1" "$2" )
            shift 2

        else
            lscmd_words+=( "$1" )
            shift
        fi
    done

    # ensure --color is honoured, despite capturing the find result with a subshell
    array_strrepl lscmd_words '--color=auto' '--color=always'

    # debug
    [[ -n ${LS_DEBUG:-} ]] &&
        declare -p lscmd_words

    ## Use find to handle the globs and exec lscmd_words
    # - actually find only needs one glob, because it won't match '.' and '..'
    # - NB bash won't either if 'globskipdots' is enabled (which is the default)
    # - NB find returns 0 even if it finds nothing
    local result

    if result=$( find "$@" -mindepth 1 -maxdepth 1 -name '.*' \
                    -exec "${lscmd_words[@]}" '{}' \+ )
    then
        if [[ -n $result ]]
        then
            printf '%s\n' "$result"
        else
            printf >&2 '%s\n' "No matches."
        fi
    fi
}
