# dependencies
import_func vrb_msg run_vrb \
    || return

: """Flatten directory tree

    Usage: flatten-dirtree [find-args] <src-dir1> ... [dest-dir]

    Move all files from source directory tree(s) to a single destination
    directory. If more than one source dir is provided, the dest-dir must be
    specified. If only a single source dir is provided, dest-dir defaults to
    the first level of the dir. If no find arguments are provided, the default
    expression is '-type f', so the following command would be run:

        find src-dir1 ... -type f -exec mv -it dest-dir '{}' +

    The '-i' argument to mv prompts before overwriting existing files. After
    the files are moved, any empty source-dirs are removed.

    If any find arguments are provided, they are inserted in the above line
    before '-type f', except for the true options (-L/-H/-P), which are
    inserted before the source dirs.

    Examples

        # move all files under abc/ into def/
        flatten-dirtree abc def

        # move all jpg files under abc/ into the root of the directory
        flatten-dirtree -name '*.jpg' abc
"""

flatten-dirtree() {

    [[ $# == 0  || $1 == @(-h|--help) ]] &&
        { docsh -TD; return; }

    local find_expr=() find_opts=() def_dd
    local src_dirs=() dest_dir

    while (( $# > 0 ))
    do
        if [[ -d "$1" ]]
        then
            src_dirs+=( "${1%/}" )
        else
            find_expr+=( "$1" )
        fi
        shift
    done

    if (( ${#src_dirs[*]} == 0 ))
    then
        err_msg 8 "no source dirs found on command line"
        return

    elif (( ${#src_dirs[*]} == 1 ))
    then
        # default dest_dir
        dest_dir=${src_dirs[0]}
        def_dd=1

    else
        # last dir was dest_dir
        dest_dir="${src_dirs[-1]}"
        unset 'src_dirs[-1]'
    fi

    # sort find options from expression
    while [[ -v 'find_expr[0]' ]] && [[ ${find_expr[0]} == @(-L|-H|-P) ]]
    do
        find_opts+=( "${find_expr[0]}" )
        find_expr=( "${find_expr[@]:1}" )
    done

    if [[ -v def_dd ]]
    then
        # prevent mv: 'abc/1' and 'abc/1' are the same file
        find_expr=( -mindepth 2 "${find_expr[@]}" )
    fi

    # default expression
    find_expr+=( -type f )


    run_vrb -P find "${find_opts[@]}" "${src_dirs[@]}" "${find_expr[@]}" \
        -exec /bin/mv -it "$dest_dir" '{}' +

    local ec=$?

    if (( ec == 0 ))
    then
        vrb_msg 0 "cleaning empty dirs..."
        # clean up
        run_vrb -P find "${src_dirs[@]}" -depth -type d -empty -print -delete

    else
        return $ec
    fi
}
