# dependencies
import_func run_vrb \
    || return

: """Print icon file names

    Usage: find-desktop-icons [search-term]

    Searches for icon files installed on the system. If the search term is provided,
    it is used to limit the results, and is treated as a case-insensitive argument to
    'find -iname'. If the search term does not contain the wildcard character '*', the
    term is sandwiched between '*' characters. This allows e.g. the search term 'loupe'
    to match the file name 'org.gnome.Loupe.svg'.

    The search is performed in the XDG_DATA_HOME and XDG_DATA_DIRS directories if those
    variables are set. Otherwise, a default set is used, comprising:

      - /usr/share/icons
      - /usr/local/share/icons
      - ~/.local/share/icons
      - /var/lib/flatpak/exports/share/icons

    The return status is 0 (true) if any icon files are printed, or 1 for no matches.
"""

find-desktop-icons() {

    [[ $# -gt 1  || ${1-} == @(-h|--help) ]] &&
        { docsh -TD; return; }

    trap '
        unset -f _add_dirs
        trap - return
    ' RETURN

    _add_dirs() {

        local d
        for d
        do
            if [[ -d $d ]]
            then
                [[ $d == @(*icons|*icons/) ]] \
                    || d=$d/icons
                dirs+=( "$d" )
            fi
        done
    }

    local dirs=()

    [[ -n ${XDG_DATA_HOME-}  && ${XDG_DATA_DIRS-} != *"$XDG_DATA_HOME"* ]] \
        && _add_dirs "$XDG_DATA_HOME"

    [[ -n ${XDG_DATA_DIRS-} ]] && {

        local dds
        mapfile -t dds < <( printf '%s\n' "$XDG_DATA_DIRS" | tr ':' '\n' )
        _add_dirs "${dds[@]}"
    }

    if [[ ! -v 'dirs[*]' ]]
    then
        _add_dirs '/usr/share' '/usr/local/share' \
            ~/.local/share /var/lib/flatpak/exports/share
    fi

    [[ -v 'dirs[*]' ]] \
        || { err_msg 2 'no dirs to search'; return; }

    local find_cmd
    find_cmd=( "$( builtin type -P find )" )
    find_cmd+=( "${dirs[@]}" )
    find_cmd+=( \( -type f -o -type l \) )

    if [[ -v 1 ]]
    then
        local trm=$1
        [[ $trm == *'*'* ]] \
            || trm="*${trm}*"

        find_cmd+=( -a -iname "$trm" )
    fi

    find_cmd+=( -print0 )

    local find_out _verb=1
    mapfile -d '' find_out < \
        <( run_vrb "${find_cmd[@]}" )

    # check find return status
    wait $! || return

    # return 1 for no matches
    [[ -v 'find_out[*]' ]] || return

    printf '%s\n' "${find_out[@]}"
}
