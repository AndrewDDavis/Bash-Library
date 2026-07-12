# dependencies
import_func path_rm \
    || return

: """Check whether two paths are symlinked, and both on PATH

    Usage: path_check_symlink [options] <path1> <path2>

    Options

      -q : suppress warning if paths are symlinked
      -r : remove path2 if paths are symlinked
"""

path_check_symlink() {

    [[ $# -lt 2  || $1 == @(-h|--help) ]] \
        && { docsh -DT; return; }

    local rm_path _v=1
    local pp1 pp2
    local flag OPTARG OPTIND=1

    while getopts ":qr" flag
    do
        case $flag in
            ( q )  (( --_v )) ;;
            ( r )  rm_path=True ;;
            ( \? ) err_msg 3 "unknown option: '-$OPTARG'"; return ;;
            ( : )  err_msg 3 "missing argument for '-$OPTARG'"; return ;;
        esac
    done
    shift $(( OPTIND-1 ))  # remove parsed options, leaving positional args

    (( $# == 2 )) ||
        { err_msg 3 "two path arguments required"; return; }

    pp1=$( builtin cd "$1"  && pwd -P )
    pp2=$( builtin cd "$2"  && pwd -P )

    if [[ $pp1 == "$pp2" ]]
    then
        [[ $_v -gt 0 ]] &&
            err_msg w "paths are symlinks: '$1', '$2'"

        if [[ ${rm_path-} == True ]]
        then
            if [[ -L $1 ]]
            then rm_path=$1
            else rm_path=$2
            fi

            [[ $_v -gt 0 ]] &&
                err_msg i "Removing path due to symlink dupes: '$rm_path'"

            PATH=$( path_rm "$rm_path" )
        fi
    fi
}
