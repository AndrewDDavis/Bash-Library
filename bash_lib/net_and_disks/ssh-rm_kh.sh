ssh-rkh() {

    : """Remove entry from known_hosts.

        Usage: ssh-rkh <name-or-IP>

        - Useful e.g. when you know that the target host's IP has changed.
        - Calls \`ssh-keygen -R ...\`.
    """

    [[ $# -eq 0 || $1 == @(-h|--help) ]] &&
        { docsh -TD; return; }

    ssh-keygen -R "$1"
}
