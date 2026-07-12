# Show a useful message on non-zero return status
#
# The output differs depending on the context, whether run for the return of
# a function, a sourced file, or a command.
#
# Usage
#
# _Case 1_: in the main lines of an interactive shell.
#
#   trap 'trap-err \$?' ERR
#
#   # Consider also something like this. This way, functions will return
#   # immediately and print an error when a command returns with non-zero status.
#   # However, the test ensures that the ERR trap won't trigger in the interactive
#   # shell. Except it does in completion functions, it would be nice if it didn't
#   # do that.
#   set -o errtrace
#   trap '
#       [[ -v FUNCNAME[0] ]] && {
#           echo \"traperr from \${FUNCNAME[0]}()\"
#           return
#       }
#   ' ERR
#
# _Case 2_: in a function, or used with functrace from an interactive shell.
#
#   # - To prevent the ERR trap 'leaking' into the enclosing shell, set both
#   #   an ERR and a RETURN trap (see below).
#   # - Using a naked return command in the ERR trap preserves the return status
#   #   of the triggering command.
#
#   foo() {
#       trap '
#           trap-err \$?
#           return
#       ' ERR
#
#       trap '
#           trap - ERR RETURN
#           # also maybe unset -f ...
#       ' RETURN
#       ...
#
#       # If there are sub-functions, you probably want 'errtrace' but not
#       # 'functrace', so that the subfunctions will return immediately and print
#       # an error when a command returns with non-zero status, but also
#
#       # extend traps to sub-functions
#       shopt -os errtrace    # functions inherit the ERR trap
#       #shopt -os functrace   # functions inherit RETURN and DEBUG traps
#   }
#
# Notes and Gotchas
#
# - Using a naked 'return' call in the ERR trap preserves the return status of the
#   command that triggered the trap.
#
# - Calling 'exit' within an EXIT trap is a special case that skips a recursive
#   run of the trap. If it's a naked 'exit' call, the return status is the value
#   on entry to the trap.
#   ref: [QA](https://unix.stackexchange.com/a/667384/85414)
#
# - Process substitution, like '<( cmd ... )', runs asynchronously, so \$? is not
#   set to the return status of 'cmd'. That makes debugging harder. You can
#   use a fifo or some [clever tricks](https://unix.stackexchange.com/a/176703/85414),
#   but finding a different way is ideal if the command could fail.
#
# - Another item to watch for: if you use a subshell during inline initialization
#   of a varaible when using 'local' or 'declare' (e.g. \`local foo=\$( cmd ... )\`),
#   the return status of the subshell is lost; the local command returns 0
#   regardless. So only use inline init with local for very simple cases.

trap-err() {

    [[ $# -eq 0  || $1 == @(-h|--help) ]] &&
        { docsh -TD; return; }

    local _rs=$1 && shift
    local _msgs=()

    # Called from sourced file, function, or interactive?
    # - see notes on Bash variables above
    if [[ -n ${FUNCNAME[1]-} ]]
    then
        # source file, contracting HOME to ~
        local _srcfn _callfn
        _srcfn=${BASH_SOURCE[1]/#"$HOME"/\~}
        _callfn=${BASH_SOURCE[2]:-main}
        _callfn=${_callfn/#"$HOME"/\~}

        # offending line
        # _call_ln=$( sed "${BASH_LINENO[0]}"'! d' "${BASH_SOURCE[1]}" )
        local _src_lns i _call_ln
        mapfile -t _src_lns < "${BASH_SOURCE[1]}"
        i=$(( BASH_LINENO[0] - 1 ))
        _call_ln=${_src_lns[i]}

        # determine whether the error was thrown by err_msg
        # - situations to support: ' { err_msg ...', ' [[ ... ]] && { err_msg ...',
        #   'case ... ) err_msg ...', leading words could include &&, ||, {, or (.
        # - all would require blanks around err_msg, except '(err_msg ...'
        # - could also sanely support leading ||, &, &&, ;
        local regptn='(^|[[:blank:]]|[(;&]|&&|\|\|)err_msg[[:blank:]]'
        if [[ "$_call_ln" =~ $regptn ]]
        then
            # error already reported by err_msg
            return

        elif [[ ${FUNCNAME[1]} == source ]]
        then
            # sourced file
            _msgs+=( "Error $_rs encountered at l. ${BASH_LINENO[0]} of" )
            _msgs+=( "  sourced file $_srcfn" )

        # elif [[ ${FUNCNAME[1]-} == docsh ]]
        # then
        #     # docsh function test to trigger printing docstr and return
        #     echo not implemented

        else
            # function
            _msgs+=( "Return status $_rs encountered in '${FUNCNAME[1]}()'," )
            _msgs+=( "  at l. ${BASH_LINENO[0]} of ${_srcfn}," )
            # below line does not seem reliable...
            _msgs+=( "  as called from ${_callfn} (? l. ${BASH_LINENO[1]}):" )
            _msgs+=( "$_call_ln" "" )
        fi

    else
        # interactive shell (probably), or script
        local _str="main-err: code $_rs"

        [[ -n ${BASH_SOURCE[0]-} ]] &&
            _str+=" in ${BASH_SOURCE[0]}"

        _msgs+=( "$_str" )
    fi

    printf >&2 '%s\n' "${_msgs[@]}"
}
