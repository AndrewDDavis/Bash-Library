# dependencies
import_func array_match \
    || return

: """Report man pages that match a keyword

    Usage: man-search [options] [[--] man-options] <search-term>

    Man-search prints the manpage names and short descriptions that match the search
    term. By default, the search term is matched against manpage names and short
    descriptions using 'man -k', which acts like apropos. The search term is treated as
    a regular expression, unless -w or -g are passed, and the search is case-
    insensitive, unless the -I man option is passed.

    Options

      -g
      : Global search mode: the search term is matched against long description sources.
        This mode treats the pattern as a simple string by default, unless -r (--regex)
        is used. This calls 'man -Kw' to obtain the matching source-file paths, then
        prints the corresponding manpage names and short descriptions by extracting them
        from the files.

      -n
      : Name search mode: the search term is only matched against manpage names, not
        their descriptions. This calls 'man -f', which acts like whatis, and adds
        --regex.

      -r (--regex)
      : Regex search: the search term is treated as a regular expression, which may
        match a substring of any word. This is the default, except in global search
        mode (-g).

      -w (--wildcard)
      : Wildcard search: the search term is treated as a wildcard (glob) pattern,
        which must match the whole manpage name or a whole word of the description.

      -v
      : Print man command lines as they are run.

    If the '--' argument is encountered, all following options are passed to man, rather
    than being processed by man-search.

    Examples

      # List manpages with xdg anywhere in the name or description (e.g. 17 results)
      man-search xdg

      # List manpages with xdg anywhere in the name (e.g. 13 results)
      man-search -n xdg

      # List manpages with names that start with xdg (e.g. 11 results)
      man-search -n '^xdg'

      # Again, using a wildcard search (e.g. 11 results)
      man-search -nw 'xdg*'

      # List manpages with XDG anywhere in the manpage text (e.g. 169 results)
      man-search -g xdg
"""

man-search() {

    [[ $# -eq 0  || $1 == @(-h|--help) ]] &&
        { docsh -TD; return; }

    # functions and namespace cleanup
    trap 'return' ERR

    trap '
        unset -f _ms_arg_parse _ms_name_search _ms_short_search _ms_global_search
        trap - err return
    ' RETURN

    _ms_arg_parse() {

        local flag OPTARG OPTIND=1
        while getopts ":gnrwv-" flag
        do
            case $flag in
                ( g )  _g=1 ;;
                ( n )  _n=1 ;;
                ( r )  man_cmd+=( --regex ) ;;
                ( w )  man_cmd+=( --wildcard ) ;;
                ( v ) (( _verb++ )) ;;
                ( - )
                    # preserve long option for man
                    # - OPTIND did not advance
                    break
                ;;
                ( \? )
                    # preserve short option for man
                    # - OPTIND advanced if flag was alone
                    p=$(( OPTIND-1 ))
                    [[ ${!p} == -$OPTARG ]] &&
                        (( OPTIND-- ))
                    break
                ;;
            esac
        done
        shift $(( OPTIND-1 ))

        _margs=( "$@" )
    }

    _ms_name_search() {

        # - NB, man -f / whatis implies --names-only
        local n=${#man_cmd[*]}
        man_cmd+=( -f --regex "${_margs[@]}" )

        # don't pass --regex if user specified --wildcard
        array_match man_cmd '--wildcard' \
            && unset 'man_cmd[n+1]'

        run_vrb "${man_cmd[@]}"
    }

    _ms_short_search() {

        # - NB, --names-only has no effect with -k / apropos
        #   e.g., 'man -k --names-only --regex xdg' returns user-dirs.conf as a result
        # - uses regex by default
        man_cmd+=( -k "${_margs[@]}" )

        run_vrb "${man_cmd[@]}"
    }

    _ms_global_search() {

        man_cmd+=( -Kw "${_margs[@]}" )

        # - man -w returns paths to man files
        local paths
        mapfile -t paths < <( run_vrb "${man_cmd[@]}" )

        # - man returns 16 for nothing found
        wait $! || return

        # extract name and short description from man files
        local p
        for p in "${paths[@]}"
        do
            local _filt mp_line mp_name mp_desc mp_secn

            # Usage of man -l:
            #   - man -l interprets arguments as nroff source files, rather than manpage
            #     names to search for
            #   - can also use -T to specify the output format
            #   - if using -Tutf8, man writes formatting escape sequences (e.g. [1m for bold text) within the file
            #   - e.g. man -l -Tutf8 ./usr/share/man/man1/uniq.1.gz > uniq_manpage.txt
            #   - usually, man passes formatted output to the less pager, but when
            #     redirecting STDOUT, man writes plain text, so we don't need -T
            #   - there is also -t, which formats for groff and is unreadable

            # sed filter to parse various formats for the name and descrip
            _filt='
                /N(AME|ame)/ {
                    n
                    # if name and desc on one line, print the line
                    / (—|-) / {p; q;}

                    # otherwise, combine the name line with the next line
                    N
                    s/-\n[[:blank:]]*/- /
                    s/\n[[:blank:]]*//
                    p; q
                }
            '
            mp_line=$( command sed -nE "$_filt" < <( command man -l "$p" 2>/dev/null ) )

            _filt='
                s/^[[:blank:]]*(.*) (—|-) (.*)[[:blank:]]*$/\1/
            '
            mp_name=$( command sed -E "$_filt" <<< "$mp_line" )

            _filt='
                s/^[[:blank:]]*(.*) (—|-) (.*)[[:blank:]]*$/\3/
            '
            mp_desc=$( command sed -E "$_filt" <<< "$mp_line" )

            # section number
            mp_secn=$( basename "${p%.gz}" )
            mp_secn=${mp_secn##*.}

            # report, adding section number
            printf '%20s - %s\n' "$mp_name ($mp_secn)" "$mp_desc"
        done
    }

    local man_cmd
    man_cmd=( "$( builtin type -P man )" ) \
        || err_msg 9 'man not found on PATH'

    # opt-parsing
    local _g _n _margs=() _verb=1
    _ms_arg_parse "$@"
    shift $#

    if [[ -v _n ]]
    then
        # name search
        _ms_name_search

    elif [[ ! -v _g ]]
    then
        # short descrip search
        _ms_short_search

    else
        # global search
        _ms_global_search
    fi
}
