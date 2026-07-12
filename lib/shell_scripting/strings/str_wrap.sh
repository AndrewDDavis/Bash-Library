# dependencies
import_func vrb_msg \
    || return

: """Wrap a string at word boundaries

    Usage: str_wrap [opts] <str>

    Wraps long lines at word breaks or '-', but preseverves existing newlines. Long
    text segments without whitespace or '-' are not wrapped.

    The default wrap width is 84, and the goal width, after which any space or '-'
    causes a wrap, is always 6 less than the wrap width.

    Options

      -i <i> : add string to start of each new line (e.g. indent with -i '    ').

      -l <l> : line break character, default \$'\n'. Only the first character of the
               argument is used, so e.g. \$'\n\r' will not work as expected.

      -w <w> : wrap width, default 84 (goal width = W-6)

    Example

      str_wrap -w60 \"\$a_string\"
"""

str_wrap() {

    [[ $# -eq 0  || $1 == @(-h|--help) ]] \
        && { docsh -TD; return; }

    trap '
        return
    ' ERR

    trap '
        unset -f _parse_args _wrapit
        trap - return
    ' RETURN

    _parse_args() {

        local flag OPTARG OPTIND=1
        while getopts "w:i:l:V" flag
        do
            case $flag in
                ( w ) w=$OPTARG ;;
                ( i ) ind=$OPTARG ;;
                ( l ) delim=$OPTARG ;;
                ( V ) (( _verb++ )) ;;
                ( * ) return 2 ;;
            esac
        done
        shift $(( OPTIND-1 ))

        (( $# == 1 )) \
            || { err_msg 3 "expected 1 arg for string"; return; }

        # split string into lines (indexed from 1)
        mapfile -t -O1 -d"$delim" str_lines < <( printf '%s'"$delim" "$1" )

        # goal width
        g=$(( w - 6 ))
        (( g > 0 )) \
            || return 4

        vrb_msg 2 "wrap width: $w (goal: $g)"
        if (( _verb > 1 ))
        then
            for (( i=0 ; i<w ; i++ )); do printf '%s' .; done
            printf '\n'
        fi
    }

    _wrapit() {

        # check each line
        local i j k ln n char ln_i bl_i
        for k in "${!str_lines[@]}"
        do
            ln=${str_lines[k]}
            vrb_msg 2 "ln[$k]: $ln"

            # ensure indent is present
            [[ k -gt 1  && -n $ind  && $ln != "$ind"* ]] \
                && ln=${ind}${ln}

            n=${#ln}

            if (( n > w ))
            then
                # step through each char of long line
                ln_i=0 bl_i=0
                for (( i=0 ; i<n ; i++ ))
                do
                    char=${ln:i:1}

                    vrb_msg 3 "$( declare -p char i ln_i bl_i )"

                    if (( ln_i > w ))
                    then
                        # max width reached
                        # - wrap at last recorded spot, if possible
                        if (( (i-bl_i) < w ))
                        then
                            j=$bl_i
                            [[ ${ln:j:1} == '-' ]] \
                                && (( j++ ))

                            ln="${ln:0:j}${delim}${ind}${ln:(bl_i+1)}"
                            bl_i=$i

                            # account for indentation
                            (( i+= ${#ind} ))
                            ln_i=${#ind}
                            continue
                        fi

                    elif (( ln_i > g ))
                    then
                        # goal width reached
                        if [[ $char == "$delim" ]]
                        then
                            # newline resets line-based index
                            if [[ -n $ind ]]
                            then
                                # account for indentation, otherwise #ind = 0
                                ln="${ln:0:i}${delim}${ind}${ln:(i+1)}"
                                (( i+= ${#ind} ))
                            fi
                            bl_i=$i
                            ln_i=${#ind}
                            continue

                        elif [[ $char == [[:blank:]] ]]
                        then
                            # replace blank(s) with newline
                            j=$(( i+1 ))
                            while { (( j < (n-1) )) && [[ ${ln:j:1} == [[:blank:]] ]]; }
                            do
                                (( j++ ))
                            done

                            ln="${ln:0:i}${delim}${ind}${ln:j}"
                            bl_i=$i

                            # account for indentation
                            (( i+= ${#ind} ))
                            ln_i=${#ind}
                            continue
                        fi
                    fi

                    if [[ $char == [[:blank:]]  || $char == '-' ]]
                    then
                        # track last blank or '-'
                        bl_i=$i
                    fi

                    (( ln_i++ ))
                done

                str_lines[k]=$ln

            # elif (( n < g ))
            # then
            #     # short line
            #     # - consider joining with the next, if it's not blank.
            fi
        done
    }

    # defaults
    local str_lines g w=84 \
        delim=$'\n' ind='' \
        _verb=1

    # parse args and split string
    _parse_args "$@"
    shift $#

    _wrapit

    printf '%s'"$delim" "${str_lines[@]}"
}
