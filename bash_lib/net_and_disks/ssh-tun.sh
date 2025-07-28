# dependencies
import_func ps-pgrep \
    || return

: """Open SSH tunnel

    Usage

        ssh-tun [options] <name-or-IP>
        ssh-tun -l

    In the first form above, runs:

      ssh -NfL <fwd_addr> <name>

    Where fwd_addr is the forwarding address, which may be specified using -L. If not
    specified, the value is '0.0.0.0:<port>:127.0.0.1:<port>', where port is 80 or the
    value given using -p.

    This opens the local port on all interfaces, and binds it to localhost on the remote
    machine specified by the given name or IP.

    The -Nf options send the ssh command to the background, and doesn't execute a remote
    command (just forwards the port).

    Options

      -l : list ssh tunnel connections. This gives a somewhat selective list of ssh
           processes that include an argument with -L.
      -p : port (default 80). This is a convenient option when using the same port on
           the local and remote machine, and you don't have to use the full -L.
      -L : forwarding address, as [bind_address:]port:host:hostport. This overrides a
           port set with -p.
"""

ssh-tun() {

    [[ $# -eq 0 || $1 == @(-h|--help) ]] \
        && { docsh -TD; return; }

    trap '
        return
    ' ERR

    trap '
        unset -f _parse_args
        trap - return err
    ' RETURN

    # defaults and options
    local ssh_cmd list
    local port=80 rhost faddr

    _parse_args() {

        ssh_cmd=$( builtin type -P ssh ) \
            || { err_msg 9 'ssh not found'; return; }

        local flag OPTARG OPTIND=1
        while getopts ':lL:p:h' flag
        do
            case $flag in
                ( L ) faddr=$OPTARG ;;
                ( p ) port=$OPTARG ;;
                ( l ) list=1 ; return; ;;
                ( h ) docsh -TD; return ;;
                ( : )  err_msg 2 "missing argument for option $OPTARG"; return ;;
                ( \? ) err_msg 3 "unknown option: '$OPTARG'"; return ;;
            esac
        done
        shift $(( OPTIND-1 ))

        [[ -v faddr ]] \
            || faddr=0.0.0.0:${port}:127.0.0.1:${port}

        # positional args
        rhost=${1:?"name or IP required"}
        shift

        (( $# == 0 )) \
            || { err_msg 5 "unexpected arg(s): '$*'"; return; }
    }

    _parse_args "$@"
    shift $#

    if [[ -v list ]]
    then
        ps-pgrep "^($ssh_cmd|ssh) .*-[[:alnum:]-]*L"

    else
        run_vrb -- "$ssh_cmd" -NfL "$faddr" "$rhost"
    fi
}
