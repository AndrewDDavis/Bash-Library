diff-filenames() {

    : """Compare filenames among directories

    Usage: diff-filenames [-s] <path1> <path2> [search-options]

    The \`find\` command is used to compare filenames from the specified directory
    paths, and only unique filenames are printed. All search options are passed to
    \`find\`.

    If the '-s' option is used, this function will explicitly report when all
    filenames are identical.

    This may also be accomplished with 'diff -qr <path1> <path2>', which reports \"Only
    in ...\" lines. However, that command is slower since it also compares the contents
    of files with the same name. The \`rsync\` command may also be used to compare files
    based on their content or metadata.

    Examples

      # compare only regular files from two directories
      diff-dir_fns dir1 dir2 -type f
    """

    local _s
    [[ ${1-} == -s ]] &&
        { _s=1; shift; }

    [[ $# -lt 2  || $1 == @(-h|--help) ]] &&
        { docsh -TD; return; }

    [[ -d $1 ]] \
        || { err_msg 3 "directory not found: '$1'"; return; }

    [[ -d $2 ]] \
        || { err_msg 3 "directory not found: '$2'"; return; }

    # find command and search roots
    local find_cmd pth1 pth2
    pth1=$1
    pth2=$2

    find_cmd=( "$( builtin type -P find )" "$@" ) \
        || return 9
    shift $#

    # get relative paths of unique filenames
    # - %P : File's path with the search starting-point removed.
    local uniq_fns
    mapfile -t uniq_fns < \
        <(  "${find_cmd[@]}" -printf '%P\n' \
                | sort \
                | uniq -u )

    if [[ ${#uniq_fns[@]} -gt 0 ]]
    then
        # add a find -path arg for each file
        find_cmd+=( '(' )

        local i
        for i in "${!uniq_fns[@]}"
        do
            [[ $i -gt 0 ]] &&
                find_cmd+=( '-o' )

            find_cmd+=( -path "${pth1}/${uniq_fns[i]}" -o -path "${pth2}/${uniq_fns[i]}" )
        done

        find_cmd+=( ')' )

        "${find_cmd[@]}"

    elif [[ -n ${_s-} ]]
    then
        printf >&2 '%s\n' "All filenames are identical."
    fi
}
