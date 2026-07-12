cp-tree() {

    : """Copy file hierarchies, preserving permissions with tar.

	Usage: cp-tree [options] <srcdir> <destdir>

	Copies full contents of srcdir to destdir, preserving permissions when
    possible. If destdir does not exist, it will be created. This function
    could be extended to work with e.g. a network location as well. See the tar
    man page for details.

    Notes:

	  - Additional options provided on the command line are passed to tar on the
      create side (e.g., for compression or exclusion of files).

	  - Internally, tar data is passed through a pipe of this form:
	  tar -cf - -C srcdir [options] . | tar -xpf - -C destdir

      - By default, cp-tree prints the tar command before running it. Use
      '-v' as the first argument to make the process more verbose.
	"

	[[ $# -lt 2 || $1 == @(-h|--help) ]] && {
	    docsh -TD
	    return
	}

    # trap ERR to cleanly return on errors
    trap '
        s=$?
        printf "%s %s\n" "${FUNCNAME[0]} returning:"
        printf "    %s\n" "status $s at l. ${BASH_LINENO[0]}," \
                        "command is $BASH_COMMAND"
        return $s
    ' ERR

    trap '
        trap - return err
    ' RETURN

    # check for verbose
    [[ $1 == -v ]] && {
        local vrb="-v"
        shift
    }

    # extract srcdir and destdir from the arguments
    local src="${@:(-2):1}"
    local dest="${@:(-1):1}"

    set -- "${@:1:$(( $# - 2 ))}"

    [[ ! -d $dest ]] &&
        run_vrb -P mkdir ${vrb:-} "$dest"

    run_vrb -P tar ${vrb:-} -cf - -C "$src" "$@" . \
        | run_vrb -P tar -xpf - -C "$dest"
}
