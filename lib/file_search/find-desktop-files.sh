# dependencies
import_func run_vrb \
    || return

: """Print desktop file names

    Usage: find-desktop-files [-q] [search-term]

    Searches for .desktop files installed on the system. If the search term is provided,
    it is used to limit the results, and is treated as a case-insensitive argument to
    'find -iname'. If the search term does not contain the wildcard character '*', the
    term is sandwiched between '*' characters. This allows e.g. the search term 'loupe'
    to match the file name 'org.gnome.Loupe.desktop'.

    The search is performed in the XDG_DATA_HOME and XDG_DATA_DIRS directories if those
    variables are set. Otherwise, a default set is used, comprising:

      - /usr/share
      - /usr/local/share
      - ~/.local/share
      - /var/lib/flatpak/exports/share

    Options

      -q : don't print results, only communicate the return status

    The return status is 0 (true) if any desktop files are printed, or 1 for no matches.
    This makes it useful for testing, e.g. to set an alias to launch a desktop file only
    if the application is installed.
"""

find-desktop-files() {

    local _q
    [[ ${1-} == -q ]] \
        && { _q=1; shift; }

    [[ $# -gt 1  || ${1-} == @(-h|--help) ]] \
        && { docsh -TD; return; }

    trap '
        unset -f _add_dirs
        trap - return
    ' RETURN

    _add_dirs() {

        local d
        for d
        do
            [[ -d $d ]] && dirs+=( "$d" )
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
    find_cmd+=( -name '*.desktop' )

    if [[ -v 1 ]]
    then
        local trm=$1
        [[ $trm == *'*'* ]] \
            || trm="*${trm}*"

        find_cmd+=( -a -iname "$trm" )
    fi

    find_cmd+=( -print0 )

    [[ -v _q ]] \
        && find_cmd+=( -quit )

    local find_out _verb=1
    mapfile -d '' find_out < \
        <( run_vrb "${find_cmd[@]}" )

    # check find return status
    wait $! || return

    # return 1 for no matches
    [[ -v 'find_out[*]' ]] || return

    [[ -v _q ]] \
        || printf '%s\n' "${find_out[@]}"
}
