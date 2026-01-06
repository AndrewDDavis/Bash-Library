: """Print count of files, links, and directories

    Usage: find-itmcnt [find-options] [paths] [find-expressions]

    The count of files, links, and directories are printed on separate lines.
    All arguments are passed to the \`find\` command. If no arguments are
    provided, the following command is run:

      find -H . -path '*/.git/*' -prune -o -type \$t

    This produces the following default behaviour:

    - The current directory tree is searched.
    - Links are not followed, except those specified on the command line.
    - Git directory contents are ignored.

    If find options (i.e. -H, -L, -P, -D or -O) or paths are provided, they
    replace those of the default find command above. Any find expressions
    replace the argments from -path to -o in the default command.

    Examples

      # count items starting with d in the directory abc
      find-itmcnt abc -name 'd*'
"""

find-itmcnt() {

    [[ ${1-} == @(-h|--help) ]] &&
        { docsh -TD; return; }

    # check for find args
    local _fopts=() _fexpr=() _paths=()
    while (( $# > 0 ))
    do
        if [[ ! -v '_paths[*]' ]] && [[ $1 == -@(H|L|P|D|O)* ]]
        then
            # true find option(s)
            if [[ $1 == -*@(D|O) ]]
            then
                _fopts+=( "$1" "$2" )
                shift
            else
                _fopts+=( "$1" )
            fi

        elif [[ $1 == -* ]]
        then
            # find expression
            _fexpr+=( "$@" )
            break

        else
            _paths+=( "$1" )
        fi
        shift
    done

    # default find args
    [[ -v '_fopts[*]' ]] \
        || _fopts=( -H )

    [[ -v '_paths[*]' ]] \
        || _paths=( . )

    [[ -v '_fexpr[*]' ]] \
        || _fexpr=( -path '*/.git/*' -prune -o )

    # print find command
    printf >&2 '%s%s\n' "$PS4" \
        "find ${_fopts[*]} ${_paths[*]} ${_fexpr[*]} -type (f|l|d)"

    # run find
    local t tarr=( files links directories )
    local n narr=() nfmt=3
    for t in "${tarr[@]}"
    do
        n=$( command find "${_fopts[@]}" "${_paths[@]}" "${_fexpr[@]}" -type ${t:0:1} | wc -l )
        narr+=( "$n" )

        # adjust format as necessary
        (( ${#n} > nfmt )) \
            && nfmt=${#n}
    done

    # formatted output
    local i
    for (( i=0 ; i<3 ; ++i ))
    do
        printf "%${nfmt}d %s\n" "${narr[i]}" "${tarr[i]}"
    done
}
