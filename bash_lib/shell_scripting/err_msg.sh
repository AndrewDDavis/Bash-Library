# dependencies
import_func is_int \
    || return

# suggestions
import_func basename

# alias for message with date
alias log_msg='err_msg -d'

: """Print log-style messages to stderr

    Usage: err_msg [-d] <rs> [\"message body\" ...]

    The value of 'rs' should be one of:

      - An integer, which sets the return status code of the err_msg call. Values
        > 0 will print an error message, 0 triggers a warning.
      - 'w' to print a warning (return status is 0).
      - 'i' to print an info message (return status is 0).
      - 'd' to print a debug message (return status is 0).

    The message body consists of 1 or more strings with diagnostic info to print
    on STDERR. If multiple strings are provided, they will each be printed on a
    separate line.

    Before the message body is printed, err_msg prints the message type and some
    context information, such as the function chain that led to the err_msg call.
    Formatting is applied to the output if STDERR is printing to an interactive
    shell.

    Options

      -d : print the date at the start of the message line

    Examples

        err_msg 1 \"valueError: foo should not be 0\"; return

        err_msg w \"file missing, that's not great but OK\"

    Notes

      - Returning from shell functions:

        For error messages, err_msg returns with a non-zero status code, which is
        commonly considered an error in shell scripting. However, that won't necessarily
        cause the calling function to return. To do that, you can:

          + Use 'return' in the calling function (this preserves the return status
            value), e.g.:

            err_msg 2 'lorem ipsum'; return

          + Set a trap in the calling function that returns on the ERR signal. For
            additional context reporting, you may use the trap-err function:

            trap '
                trap-err \$?
                return
            ' ERR

    Background

      - A common framework for [log severity levels][^1] is:

        0: emerg
        1: alert
        2: crit
        3: err
        4: warning
        5: notice
        6: info
        7: debug

        [^1]: https://en.wikipedia.org/wiki/Syslog#Severity_level
"""

err_msg() {

    [[ $# -eq 0  || $1 == @(-h|--help) ]] \
        && { docsh -TD; return; }

    # date option
    local _d
    [[ $1 != '-d' ]] \
        || { _d=1; shift; }

    # Return status (exit code) and severity level
    {
        local severity=ERROR
        local -i rs

        case $1 in
            ( w | 0 )
                severity=WARNING
                rs=0
            ;;
            ( i )
                severity=INFO
                rs=0
            ;;
            ( d )
                severity=DEBUG
                rs=0
            ;;
            ( * )
                is_int "$1" \
                    && rs=$1 \
                    || { printf >&2 '%s\n' "unknown rs: '$rs'"; return; }
            ;;
        esac
        shift
    }

    # Remaining args define message body
    {
        local body_lines
        if [[ $# -eq 0 ]]
        then
            # Use generic message if none was supplied
            body_lines=( "return status was $rs" )

        else
            # Split multi-line messages into array of lines
            mapfile -t body_lines < \
                    <( printf '%s\n' "$@" )
            shift $#
        fi
    }

    ## Define context of err_msg call (function name, source file, line)
    {
        local -A caller=( [name]='' [srcnm]='' [srcln]='' )
        local context report=()

        # - calling function names (if any)
        [[ -v 'FUNCNAME[1]' ]] && {

            caller[name]=${FUNCNAME[1]}

            [[ ${FUNCNAME[1]} == @(main|source) ]] \
                || caller[name]+='()'

            if [[ -v 'FUNCNAME[2]'  && $severity == @(ERROR|WARNING) ]]
            then
                local i
                for (( i=2; i<${#FUNCNAME[*]}; i++ ))
                do
                    caller[name]+=", ${FUNCNAME[i]}"
                done
            fi
        }

        # - caller source file (can also be 'main', 'source', or 'environment')
        caller[srcnm]=$( basename "${BASH_SOURCE[1]-}" )

        # - calling line in source file (or line of interactive shell)
        # - refers to a condensed form of the calling function, as seen by 'type'
        caller[srcln]=${BASH_LINENO[0]-}

        # create message string(s) to report context
        if [[ -z ${caller[name]}  && -z ${caller[srcnm]} ]]
        then
            # e.g. interactive shell
            context="(unknown source, l. ${caller[srcln]})"

        elif [[ -z ${caller[name]}  && -n ${caller[srcnm]} ]]
        then
            # unknown name, but has a file
            context="${caller[srcnm]}, l. ${caller[srcln]}'"

        elif [[ ${caller[name]:(-2)} != '()' && -n ${caller[srcnm]} ]]
        then
            # not a function, but named e.g. 'source' or 'main'
            context="${caller[name]} (l. ${caller[srcln]}) in '${caller[srcnm]}'"

        elif [[ $rs -eq 0 ]]
        then
            # e.g. warning from a function
            context=${caller[name]}

        else
            context="${caller[name]} in '${caller[srcnm]}'"
        fi

        [[ $rs -gt 0 ]] \
            && context="code $rs from $context"
    }

    report=( "${_d+"$( date +'%F %T %Z' ) "}[$severity] ${context}:" )

    ## For low-severity messages, try to fit on one line
    {
        local _ol_report
        if [[ $rs -eq 0
            && ${#body_lines[*]} -eq 1 ]]
        then
            _ol_report="${report[0]}  ${body_lines[*]}"

            [[ ${#_ol_report} -lt $( tput cols ) ]] \
                || unset _ol_report
        fi
    }

    ## Format context strings
    if [[ -t 2 ]]
    then
        # Define ANSI strings for text styles
        # - Not using _cbo from 'csi_strvars -d' function, as it has prompt ignore
        #   chars in it too (like \001), which messes up 'less' display
        local _bld=$'\e[1m' _rsb=$'\e[22m' \
            _dim=$'\e[2m' _rsd=$'\e[22m' \
            _ita=$'\e[3m' _rsi=$'\e[23m' \
            _uln=$'\e[4m' _rsu=$'\e[24m' \
            _rst=$'\e[0m'

        # Bold errors and warnings
        [[ $severity == @(ERROR|WARNING) ]] \
            && report[0]=${report[0]/#"[${severity}]"/"[${_bld}${severity}${_rsb}]"}

        # Underline file, if present (don't bold function, was too much)
        report[0]=${report[0]/%"${caller[srcnm]}'"/"${_uln}${caller[srcnm]}${_rsu}'"}
    fi


    ## Print formatted context, then message body with standardized indentation
    if [[ -v _ol_report ]]
    then
        # one-liner, like _ol_report with formatting
        report[0]+="  ${body_lines[*]}"

    else
        # body line(s) with consistent indentation
        local ln _ind='    '
        for ln in "${body_lines[@]}"
        do
            [[ $ln =~ ^([[:blank:]]*)(.*)$ ]]
            report+=( "${_ind}${BASH_REMATCH[2]}" )
        done

        # add blank line above and below errors
        [[ $rs -gt 0 ]] \
            && report=( '' "${report[@]}" '' )
    fi

    printf >&2 '%s\n' "${report[@]}"
    return $rs
}
