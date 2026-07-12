lfcd () {

    : """Change shell working dir using lf file manager

        You may also like to assign a key (e.g. Ctrl-O) to this command, e.g.:

          bind '\"\\C-o\":\"lfcd\\C-m\"'  # bash
          bindkey -s '^o' 'lfcd\\n'  # zsh
    """

    [[ $# -eq 0  || $1 == @(-h|--help) ]] &&
        { docsh -TD; return; }

    local _lfwd

    # - use 'command' in case `lfcd` is aliased to `lf`
    if _lfwd=$( command lf -print-last-dir "$@" )
    then
        cd "$_lfwd"
    fi
}
