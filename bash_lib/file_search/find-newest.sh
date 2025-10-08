# dependencies
import_func run_vrb \
    || return

: """Find newest files in a directory tree

    Usage: find-newest [-n N] [find-options] [paths] [find-expressions]

    Other than the -n option, all arguments are passed to the \`find\` command.
    The results are printed in a format that includes the modification date, and
    then \`sort\` and \`head\` are used to limit the results.

    If no expressions are provided for find, the following command is run:
    \`find -L . -name .git -prune -o -type f\`
    If only find-options (i.e. -H, -L, -P, -D or -O) or paths are provided, the
    same find command is run, with the provided arguments in place of '-L .'.

    The '-n' option may be used to limit the results to the newest N files
    (default 12).

    Examples

      # newest 6 files or symlinks with extension .sh under the current directory
      find-newest -n 6 -L . -type f -name '*.sh'

      # newest 12 files modified in the last week, not including those in .git/
      find-newest -L . -name .git -prune -o \( -type f -mtime 7 \)
"""

find-newest() {

    [[ ${1-} == @(-h|--help) ]] &&
        { docsh -TD; return; }

    # defaults and args
    local -i n_lines=12

    local i flag OPTARG OPTIND=1
    while getopts ':n:' flag
    do
        i=$(( OPTIND-1 ))
        case $flag in
            ( n )
                # arg should be positive int
                if is_int -p "$OPTARG"
                then
                    n_lines=$OPTARG

                elif [[ ${!i} == -n* ]]
                then
                    # may have been a find option like '-name'
                    (( OPTIND-- ))
                    break

                else
                    # invalid arg, like '-n NAN'
                    err_msg 3 "invalid argument for -n: '$OPTARG'"
                    return
                fi
            ;;
            ( \? )
                # Unknown option: preserve it for 'find'
                # - check if OPTIND was incremented (e.g. arg was '-a')
                [[ ${!i} == -"$OPTARG" ]] \
                    && (( OPTIND-- ))
                break
            ;;
            ( : )
                err_msg 2 "missing argument for '$OPTARG'"
                return
            ;;
        esac
    done
    shift $(( OPTIND-1 ))

    # check for find args
    local -i _expr=0 _fopt=0 _path=0
    local arg
    for arg in "$@"
    do
        if (( _path == 0 )) && [[ $arg == -@(H|L|P|D|O) ]]
        then
            # true find option
            _fopt=1
            continue

        elif [[ $arg == -* ]]
        then
            # find expression was passed
            _expr=1
            break

        else
            # path
            _path=1
        fi
    done

    if ! (( _expr ))
    then
        # by default, list files, but exclude .git

        # default to search in current dir with -L
        (( $# == 0 )) \
            && set -- -L .

        set -- "$@" -name .git -prune -o -type f
    fi

    run_vrb -P find "$@" -printf "%TF %TH:%TM %p\n" \
        | command sort -rn \
        | command head -n $n_lines
}
