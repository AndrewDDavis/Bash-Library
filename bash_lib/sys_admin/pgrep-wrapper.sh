# useful pgrep aliases
alias pgrep-showname='pgrep -fl'
alias pgrep-showcmd='pgrep -fa'

: """Convenient pgrep aliases

    Usage: pgrep-wrapper [options] <ERE pattern>

    The pgrep command matches a pattern against running commands, and
    usually outputs matching pids, 1 per line. This function is aliased
    for common option groupings that print more info. All arguments are
    passed to pgrep.

    See other useful constructs in the ps-pgrep function.

    Notable pgrep options:

      -f : match against full command line
      -l : print process name as well as PID
      -a : print full command line as well as PID

    Aliases defined above:

      pgrep-showcmd='pgrep -fa'
      pgrep-showname='pgrep -fl'
"""

pgrep-wrapper() {

    [[ $# -eq 0  || $1 == @(-h|--help) ]] \
        && { docsh -TD; return; }

    command pgrep "$@"
}
