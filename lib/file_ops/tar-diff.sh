tar-diff() {

    : """Compare archive files against the file-system

        Usage: tar-diff [-v] <archive> [path ...]

        This wrapper function shows a comparison between the files in an archive against
        those on the filesystem. Optional file paths represent files in the archive, not
        on disk. It reports differences in file size, mode, owner, modification date and
        contents. Any files in the file system that do not have corresponding archive
        members are ignored.

        Using -v once causes files to be printed as they're checked. Using it again
        causes extra file info to be printed, like 'ls -l'.

        Returns 1 if some files differed.
    """

	[[ $# -eq 0  || $1 == @(-h|--help) ]] &&
	    { docsh -TD; return; }

    local tar_cmd
    tar_cmd=( "$( builtin type -P tar )" -d )

    # refer to _chk_tarv funtion from the tarc.sh file
    # - checks tar version
    # - diff only supported for GNU?

    # _chk_tarv

    # shift away option flags
    while [[ -v 1  && $1 == -* ]]
    do
        tar_cmd+=( "$1" )
        shift
    done

    "${tar_cmd[@]}" -f "$@"
}
