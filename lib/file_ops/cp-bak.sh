# dependencies
import_func vrb_msg \
    || return

# mkbak may be more mnemonic
mkbak() {
    # alias to cp-bak
    cp-bak "$@"
}

: """Create simple file backup copies

    Usage : cp-bak [opts] [--] [cp-opts] <filename> ...

    Options (unrecognized options are passed on to cp):

      -d <dir>
      : create copy in dir, rather than next to input file

      -e <.foo>
      : use extension .foo (or e.g. '~') instead of .bak

      -o
      : use .old extension instead of .bak

      -O
      : use .orig extension instead of .bak

      -q
      : omit verbose copy output

      -v
      : show result of copy using 'ls -l' (-vv to also show verbose copy op)

    cp-bak makes a copy of each filename, creating a unique file name by
    appending .bak and possibly an integer, as necessary. The copy is performed
    using 'cp -pi' by default, to preserve permissons and modification times, and
    not clobber existing files.

    A warning is printed if the file copy differs from the original in permissions
    or ownership. Since cp dereferences symlinks by default, this check does too.

    This function is intended for simple file backups, e.g. when editing config
    files, to allow quick reversion of changes. For a full incremental backup
    solution, use e.g. borg-go or tar.
"""

cp-bak() (

    [[ $# -eq 0  || $1 == @(-h|--help) ]] \
        && { docsh -TD; return; }

    # return and errors and clean up on return
    trap '
        return
    ' ERR

    trap '
        unset -f _parse_opts _show_stats _chk_stats
        trap - err return
    ' RETURN

    _parse_opts() {

        local flag OPTARG OPTIND=1
        while getopts ":d:e:oOqv" flag
        do
            case $flag in
                ( d ) odir=${OPTARG%/} ;;
                ( e ) bk_ext=$OPTARG ;;
                ( o ) bk_ext=.old ;;
                ( O ) bk_ext=.orig ;;
                ( q ) (( _verb-- )) ;;
                ( v ) (( _verb++ )) ;;
                ( \? ) cp_opts+=( -"$OPTARG" ) ;;
                ( : ) err_msg 3 "missing arg for $OPTARG"; return ;;
            esac
        done
        n=$(( OPTIND-1 ))

        # verbose copy operation
        if (( _verb == 1 || _verb > 2 ))
        then
            cp_opts+=( -v )
        fi
    }

    _show_stats() {

        trap 'return' ERR
        trap 'trap - err return' RETURN

        # print mode (octal), user and group IDs in expected format
        # args: filename
        stat -L --format='%04a %u:%g' "$1"
    }

    _chk_stats() {

        # check for consistent metadata
        trap 'return' ERR
        trap 'trap - err return' RETURN

        # keep local as a separate cmd, to retain return status
        local -i l
        local l _msg f1_stats f2_stats

        # don't use proc subst, so we retain the return status
        #read -r f1_md f1_ug < <( _show_stats "$1" )
        #read -r f2_md f2_ug < <( _show_stats "$2" )
        f1_stats=( $( _show_stats "$1" ) )
        f2_stats=( $( _show_stats "$2" ) )

        # minimum filename string length
        l=8
        (( ${#1} > l )) && l=${#1}
        (( ${#2} > l )) && l=${#2}

        # mode
        if [[ ${f1_stats[0]} != "${f2_stats[0]}" ]]
        then
            # show a warning message for differences
            printf -v _msg "%-${l}s  %6s\n" \
                "filename" "mode" \
                "$( str_rep - $l )" "$( str_rep - 6 )" \
                "$1" "${f1_stats[0]}" \
                "$2" "${f2_stats[0]}"

            printf '\n'
            err_msg w "$_msg"
        fi

        # ownership
        if [[ ${f1_stats[1]} != "${f2_stats[1]}" ]]
        then
            printf -v _msg "%-${l}s  %12s\n" \
                "filename" "owner:group" \
                "$( str_rep - $l )" "$( str_rep - 12 )" \
                "$1" "${f1_stats[1]}" \
                "$2" "${f2_stats[1]}"

            printf '\n'
            err_msg w "$_msg"
        fi
    }

    # defaults and args
    local odir \
        bk_ext=.bak \
        cp_opts=( -pi ) \
        _verb=1

    # parse options
    local n
    _parse_opts "$@"
    shift "$n"

    for fn in "$@"
    do
        [[ -d $fn ]] && {
            err_msg w "dirs not supported (try tar); skipping ${fn}"
            continue
        }

        # split fn
        local fbn fdn
        fbn=$( basename "$fn" )
        fdn=$( dirname "$fn" )

        # add ./ for relative paths, for consistency of later reporting
        [[ $fdn == '.'  &&  ${fn:0:2} != './' ]] &&
            fn="./$fn"

        # if file already has .bak, make abc.bak2 instead of abc.bak.bak
        [[ $fn == *${bk_ext} ]] &&
            bk_ext=''

        # output to same dir unless otherwise specified
        [[ -z ${odir:-} ]] &&
            odir=$fdn

        # propose new filename
        bk_fn=${odir}/${fbn}${bk_ext}

        # add integer as necessary
        local -i i=1
        while [[ -e ${bk_fn} ]]
        do
            (( i++ ))
            bk_fn=${odir}/${fbn}${bk_ext}${i}

            if (( i > 99 ))
            then
                err_msg 2 "found 99 backup files for $fn, aborting."
                return 2
            fi
        done

        # perform copy
        command cp "${cp_opts[@]}" "$fn" "$bk_fn"

        # check metadata consistency of copy
        _chk_stats "$fn" "$bk_fn"

        if (( _verb > 1 ))
        then
            printf '\n%s\n' "Result:"
            command ls -l "$fn" "$bk_fn"
            printf '\n'
        fi
    done
)
