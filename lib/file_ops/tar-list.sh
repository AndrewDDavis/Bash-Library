tar-list() {

    : """List files in a tar archive

    Usage: tar-list [tar-options] <archive-file>

    This function runs 'tar -tv -Gv' on the supplied archive filename, along with any
    other options supplied.

    The -t option directs tar to list the file paths, and the -v increases the
    verbosity so that file permissions, ownership, size, and modification times are
    shown, similar to 'ls -l'.

    The extra -G and -v options have no effect for regular archives, but print extra
    information for incremental archives that shows which files were included and
    excluded when the archive was made.

    Notes

      - Tar starts listing right away, but must read the header for each file block
        before it can finish the list. The file blocks occur sequentially throughout
        the file, so this entails reading the whole file before the listing
        operation completes. As long as the file is seekable (force with -n), this
        may not be too bad.

      - If a large archive is commonly listed, better archive formats include [zip](https://askubuntu.com/a/1036234/52041)
        and possibly [dar](https://github.com/Edrusb/DAR), and tpxz.
    """

    [[ $# -eq 0  || $1 == @(-h|--help) ]] &&
        { docsh -TD; return; }

    local tar_cmd
    tar_cmd=( "$( builtin type -P tar )" -tv -Gv )

    # archive filename must be last arg
    tar_cmd+=( "${@:1:$#-1}" -f "${!#}" )

    ( set -x
    "${tar_cmd[@]}"
    )
}
