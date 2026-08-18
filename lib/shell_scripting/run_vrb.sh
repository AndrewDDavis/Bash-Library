# dependencies
import_func is_int \
    || return

: """Print command line to STDERR as it is being run

    Usage: run_vrb [options] [--] <command-line ...>

    This function runs the command line provided. If the verbosity setting is high
    enough, the command line is printed on STDERR as it is executed, prepended by
    the \$PS4 string (usually '+ '). This is accomplished by temporarily enabling
    the xtrace (set -x) shell option.

    The verbosity setting is established by looking for a shell variable called '_v'
    or '_verb' with a numerical value. If no such variable is found, the default
    value is 2, which may be changed using the -v option. The verbosity threshold
    is 1, above which the command line is printed.

    Options

      -v <n>
      : set verbosity level to integer value n.

      -P
      : resolve the command name to either a shell builtin or file on the PATH, and
        modify the command line to be explicit about what is run (i.e. either
        'builtin command' or '/path/to/command').

    If environment variable settings in the form of A=B are used at the start of the
    command line, the env command is prepended to ensure the command runs. Note that
    env is incompatible with running shell functions or builtins, so an alternative
    command line in the form of 'A=B run_vrb command args' is recommended.

    If the command is a shell function, not only the function call is printed to
    STDERR, but also the commands within the function.

    The return status code is usually the return status of the command line, but may
    be 2 if there was an option problem, or 124-6 if there was a problem determining
    the command name or type.

    Examples

      run_vrb git clone http://repo-url.com dir

      _v=1
      [[ \$foo == bar ]] && (( _v++ ))
      run_vrb -\$_v borg-go create
"""

run_vrb() {

    [[ $# -eq 0  || $1 == @(-h|--help) ]] \
        && { docsh -TD; return; }

    # err trap and cleanup routine
    trap '
        return
    ' ERR

    trap '
        unset -f _parse_opts _parse_posargs _rslv_cmd
        trap - err return
    ' RETURN

    _parse_opts() {

        if [[ ! -v _verb ]]
        then
            # verbosity was not inherited
            if [[ -v _v ]]
            then
                _verb=$_v
            else
                _verb=2
            fi
        fi

        # parse options
        # - NB, getopts breaks the loop on '--' and advances OPTIND
        local flag OPTARG OPTIND=1
        while getopts ':v:P' flag
        do
            case $flag in
                ( v ) _verb=$OPTARG ;;
                ( P ) _P=1 ;;
                ( \? ) err_msg 2 "unknown option: '$OPTARG'"; return ;;
                ( : )  err_msg 3 "missing argument for '$OPTARG'"; return ;;
            esac
        done
        n=$(( OPTIND-1 ))

        is_int "$_verb" \
            || { err_msg 2 "non-integer verbosity: '$_verb'"; return; }
    }

    _parse_posargs() {

        # categorize the words of the command-line into A=B args, the command name,
        # and command args
        # - NB, I used to use array_match() in here, but that caused a function loop (!)

        # detect env command (must be first)
        if [[ $1 == @(env|*/env) ]]
        then
            env_args+=( "$1" )
            shift
        fi

        while [[ -v 1 ]]
        do
            if [[ $1 == *=* ]]
            then
                # env-var setting
                # - ensure env command
                [[ -v env_args[*] ]] \
                    || env_args+=( "$( builtin type -P env )" )

                env_args+=( "$1" )

            else
                # command, followed by args
                cmd_args=( "$@" )
                shift $#
                break
            fi
            shift
        done

        [[ -n ${cmd_args[*]} ]] \
            || { err_msg 124 "no command detected"; return; }
    }

    _rslv_cmd() {

        # resolve command to builtin or file
        # - NB, 'type -at' returns multi-line string containing alias, keyword,
        #   function, builtin, file or ''
        local types
        types=$( builtin type -at "${cmd_args[0]}" ) \
            || {
            err_msg 125 "type failure for command: '${cmd_args[0]}'"
            return
        }

        # adjust command argument
        case $types in
            ( *builtin* )
                [[ -z ${env_args[*]} ]] \
                    || { err_msg 9 "builtins (${cmd_args[0]}) not compatible with env"; return; }

                [[ ${cmd_args[0]} == builtin ]] \
                    || cmd_args=( builtin "${cmd_args[@]}" )
            ;;
            ( *file* )
                # NB, if cmd is a path already, type -P just gives it back
                cmd_args[0]=$( builtin type -P "${cmd_args[0]}" )
            ;;
            ( * )
                err_msg 126 "command is not a builtin or file: '${cmd_args[0]}'"
                return
            ;;
        esac
    }

    # define options and verbosity setting
    local -I _verb
    local -i n _P
    _parse_opts "$@"
    shift $n

    # parse positional args and define the command line to be executed
    local env_args=() cmd_args=()
    _parse_posargs "$@"
    shift $#

    if [[ -v _P ]]
    then
        # resolve command name
        _rslv_cmd
    fi

    local setx
    if [[ _verb -gt 1  && $- != *x* ]]
    then
        # enable xtrace
        setx=1
        set -x
    fi

    # run command line
    { local -i ec=0; } 2>/dev/null

    "${env_args[@]}" "${cmd_args[@]}" \
        || { ec=$?; } 2>/dev/null

    {
        # reset xtrace
        [[ -v setx ]] \
            && set +x
    } 2>/dev/null

    return $ec
}
