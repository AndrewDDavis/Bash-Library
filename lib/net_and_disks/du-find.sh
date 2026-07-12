# dependencies
import_func array_match array_strrepl array_max \
    || return

du-find() {

    : """Match files using find or fd, show disk usage with du

        Usage: du-find [--fd] [find-or-fd-arguments]

        All arguments are passed to find, which is used to match files. The function
        then runs 'du -ahcSD' to print the disk usage of each file, and a summary line.
        The results are ordered using 'sort -h'. Refer to the du and find manpages for
        option details.

        The function adds -print0 after the find arguments, unless it is already
        present, e.g. when doing '-prune -o \( ... -print0 \)'.

        With option --fd, the fd command is used to match files, rather than find.
    """

	[[ $# -eq 1  && $1 == @(-h|--help) ]] &&
    	{ docsh -TD; return; }


    ## These all work, produce equivalent output:
    #
    # find . -type f -exec du -ahcSD {} +
    #
    # find . -type f -print0 | xargs -r0 du -ahcSD
    #
    # find . -type f -print0 | du -ahcSD --files0-from=-
    # or, equivalently:
    # du -ahcSD --files0-from=- < <( find . -type f -print0 )

    # In my testing, in a documents dir with 9000 files, piping the output of find
    # straight into du was slightly faster. E.g. ~ 95 ms for find -> du, ~ 140 ms for
    # find -> xargs, and ~ 150 ms for find -exec. In a dir with only 200 files, the
    # difference was much lower.


    # all arguments passed to find or fd
    local fd_args fd_cmd

    fd_args=( "$@" )
    shift $#

    # check for --fd
    if array_strrepl fd_args '--fd'
    then
        fd_cmd=$( builtin type -P fd ) \
            || fd_cmd=$( builtin type -P fdfind ) \
                || return 9

        # check for -0 or --print0
        array_match fd_args '-0|--print0' \
            || fd_args+=( '--print0' )

    else
        fd_cmd=$( builtin type -P find ) \
            || return 9

        # check for -print0
        array_match -F fd_args '-print0' \
            || fd_args+=( '-print0' )
    fi



    # further processing from du and sort
    # - NB, du assumes tab-stops every 8, it seems, so the sed command
    #   fixes the output if tabs were set to 4
    local du_cmd srt_cmd sed_cmd

    du_cmd=( "$( builtin type -P du )" -ahcSD --files0-from=- ) \
        || return 9

    srt_cmd=( "$( builtin type -P sort )" -h ) \
        || return 9

    sed_cmd=( "$( builtin type -P sed )" -E 's/^((.|..|...)\t)/\1\t/' ) \
        || return 9

    # run the chain, minding all return status codes
    local ps
    "$fd_cmd" "${fd_args[@]}" \
        | "${du_cmd[@]}" \
        | "${srt_cmd[@]}" \
        | "${sed_cmd[@]}"

    ps=( "${PIPESTATUS[@]}" )
    return "$( array_max ps )"
}
