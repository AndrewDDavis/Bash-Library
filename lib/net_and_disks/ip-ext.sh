ip-ext() {

    : """Print the external IP of the current machine

        Usage: ip-ext [-6]

        This function uses curl to query ifconfig.co and obtain the IP. It
        defaults to using IPv4; use '-6' to get IPv6 address.
    """

    [[ $# > 1  ||  ${1-} == @(-h|--help) ]] &&
        { docsh -TD; return; }

    # args and vars
    local ipv=4

    [[ ${1-} == -6 ]] && {
        ipv=6
        shift
    }

    curl -${ipv} ifconfig.co
}
