mst() {

    : """Search for files using mate-search-tool

    Usage: mst [options] [pattern [root-dir]]

    This function launches \`mate-search-tool\` with the '--follow' and '--hidden'
    options, to show hidden files and follow symlinks. If no root-dir is specified for
    the search, --path='.' is added to the command line.

    If a pattern is provided, it is interpreted as a regex pattern matching a substring
    of the filename, and the search is started immediately. The regex syntax seems a bit
    quirky: it appears to be ERE, as meta-charcters like '+', '(', and '|' do not
    require a leading '\'. However, to match literal '.', use '[.]' rather than '\.'.

    To start a search using a glob pattern or substring of the filename, use
    --named='pattern'. If the pattern contains no globbing characters, it is interpreted
    as a substring (i.e. the glob '*pattern*').

    For documentation of all options, refer to the \`mate-search-tool\` manpage. For
    more complete documentation of the application, refer to 'Search for Files' in the
    Gnome help browser application.
    """

    [[ ${1-} == @(-h|--help) ]] &&
        { docsh -TD; return; }

    local mst_pth mst_cmd
    mst_pth=$( builtin type -P mate-search-tool ) \
        || return 9

    mst_cmd=( "$mst_pth" --follow --hidden )

    # filter args for positional (non-option) args
    # - m-s-t only takes arguments of the form --flag or --flag=value
    local -i n=0

    while [[ -v 1 ]]
    do
        if [[ $1 == -* ]]
        then
            # option
            mst_cmd+=( "$1" )

        else
            if [[ $n -eq 0 ]]
            then
                # 1st posnl arg is pattern
                mst_cmd+=( --regex="$1" --start )

            elif [[ $n -eq 1 ]]
            then
                # 2nd posnl arg is path
                mst_cmd+=( --path="$1" )

            else
                err_msg 3 "too many positional args"
                return
            fi
            (( ++n ))
        fi

        shift
    done

    [[ $n -lt 2 ]] &&
        mst_cmd+=( --path='.' )

    (
        set -x
        "${mst_cmd[@]}" &
    )
}
