: """Remove entry from known_hosts.

    Usage: ssh-rm_kh <name-or-IP>

    - Useful e.g. when you know that the target host's IP has changed.
    - Calls \`ssh-keygen -R ...\`.
"""

ssh-rm_kh() {

    [[ $# -eq 0 || $1 == @(-h|--help) ]] \
        && { docsh -TD; return; }

    ssh-keygen -R "$1"
}
