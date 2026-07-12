rg-files() {

    : """Search for files using ripgrep

    Calls rg with the following options:

      -l (--files-with-matches)
      -. (--hidden)
      -L (--follow)
      -S (--smart-case)
      --no-unicode
      --no-ignore-vcs
      --no-ignore-exclude
      --no-ignore-global
    """

    [[ $# -eq 0  || $1 == @(-h|--help) ]] &&
        { docsh -TD; return; }

    local rg_cmd
    rg_cmd=$( builtin type -P rg ) \
        || return 9

    "$rg_cmd" -l.LS \
        --no-unicode \
        --no-ignore-vcs \
        --no-ignore-exclude \
        --no-ignore-global \
        "$@"
}
