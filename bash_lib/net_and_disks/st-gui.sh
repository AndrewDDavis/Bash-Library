: """Connect to local or remote Syncthing GUI

    Usage: st-gui [[ssh-options ...] user@hostname]

    When no arguments are issued on the command line, st-gui opens a browser
    window that connects to the local Syncthing instance. When a destination
    is specified, st-gui opens an SSH tunnel to that machine on local port
    58384, which connects to the remote Syncthing instance.

    Examples

      # connect to local GUI in the browser
      st-gui

      # connect to a remote GUI on the LAN
      st-gui user@lanhost

      # connect to a remote GUI with a custom port
      st-gui -o port=52222 user@example.ca
"""

st-gui() {

    [[ $# -gt 0 && $1 == @(-h|--help) ]] &&
        { docsh -TD; return; }

    if (( $# == 0 ))
    then
        command syncthing --browser-only

    else
        local ssh_cmd
        ssh_cmd=$( builtin type -P ssh ) \
            || return 5

        # Defaults and args
        local ssh_opts=()
        local hostnm

        while (( $# > 0 ))
        do
            if [[ $1 == *@* ]]
            then
                hostnm=$1
            else
                ssh_opts+=( "$1" )
            fi
            shift
        done

        [[ -v hostnm ]] \
            || { err_msg 2 "destination required on command line"; return; }

        # set up the tunnel: bind localhost:lport to remote's local port 8384
        # - `ssh -fNL ...` runs no command and goes to background immediately
        # - `ssh -fL ... sleep 300` waits for 5 min for a program to start using the
        #   tunnel, and exits if nothing starts using it
        local lport=58384
        local ssh_args=()

        ssh_args=( -fL "localhost:${lport}:localhost:8384" )
        ssh_args+=( "${ssh_opts[@]}" )
        ssh_args+=( "$hostnm" )
        ssh_args+=( sleep 300 )

        if "$ssh_cmd" "${ssh_args[@]}"
        then
            printf >&2 '\n%s\n' "View Syncthing GUI for ${hostnm} at <http://localhost:$lport>"

        else
            local -i ssh_ec=$?
            printf >&2 '%s\n' "An error occurred"
            printf >&2 '%s\n' "Output of 'lsof -i :$lport':"
            lsof -i ":$lport"
            return $ssh_ec
        fi
    fi
}
