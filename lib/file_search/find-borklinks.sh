: """Print broken symlinks within a directory tree

    Usage: find-borklinks [path] [find-args]

    By default, find-borklinks runs the find command with the expression
    '-type l -xtype l'. This has the effect of finding only broken symbolic links.
    By default, the command searches under the current directory tree, but an
    alternate path may be specified. All arguments are passed to the 'find'
    command; refer to the manpage for details.
"""

find-borklinks() {

    [[ $# -gt 0 && $1 == @(-h|--help) ]] \
        && { docsh -TD; return; }

    local path findopts=() findexpr=()
    while (( $# > 0 ))
    do
        # sort out find options, arguments, and path
        case $1 in
            ( -D | -O )
                findopts+=( "$1" "$2" )
                shift 2
                continue
                ;;
            ( -H | -L | -P | -D* | -O* )
                findopts+=( "$1" )
                shift
                continue
                ;;
        esac

        if [[ $1 != -* && ! -v path ]]
        then
            path=$1
            shift
            continue
        else
            findexpr=( "$@" )
            shift $#
            break
        fi
    done

    # Re. non-broken symlinks:
    # - this style generally works, but will follow symlinks in the tree:
    #       find -L "$@" -type l
    # - the below style doesn't follow symlinks, unless user issues -L

    run_vrb -v1 -P \
        find "${findopts[@]}" ${path+"$path"} \
        -type l -xtype l \
        "${findexpr[@]}"
}
