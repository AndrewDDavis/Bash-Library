ping-ci() {

    : """ping 10 times at 250 ms

    Usage

      ping-ci [options] <address>

      - for iputils ping, report late responses using -O
      - any further arguments are passed to ping
    """

    # print docstrings
    [[ $# -eq 0  || $1 == @(-h|--help) ]] \
        && { docsh -TD; return 0; }

    # parse args, define vars
    local opts=(-c 10 -i 0.25)

    ping -c 1 -O 127.0.0.1 &>/dev/null && {
        opts+=(-O)
    }

    # main operation
    ping "${opts[@]}" "$@"
}
