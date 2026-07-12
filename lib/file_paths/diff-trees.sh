diff-trees() {

    : """Compare filenames between two filesystem trees

    Usage: diff-trees <path1> <path2> [tree-options]

    The \`diff -us\` command is used to compare the output of the tree command applied
    to the specified directory paths. Unique filenames are printed, with 3 lines of
    context above and below. The context may or may not include the ascii representation
    of all containing directories for the unique files.

    See also diff-filenames.
    """

    [[ $# -lt 2  || $1 == @(-h|--help) ]] &&
        { docsh -TD; return; }

    [[ -d $1 ]] \
        || { err_msg 3 "directory not found: '$1'"; return; }

    [[ -d $2 ]] \
        || { err_msg 3 "directory not found: '$2'"; return; }

    # search roots
    local pth1 pth2
    pth1=$1
    pth2=$2
    shift 2

    # diff command
    diff_cmd=( "$( builtin type -P diff )" -us ) \
        || return 9

    [[ -t 1 ]] \
        && diff_cmd+=( --color=auto )

    # tree command
    tree_cmd=( "$( builtin type -P tree )" "$@" ) \
        || return 9
    shift $#

    "${diff_cmd[@]}" <( "${tree_cmd[@]}" "$pth1" ) <( "${tree_cmd[@]}" "$pth2" )
}
