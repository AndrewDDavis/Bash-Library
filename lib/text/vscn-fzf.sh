vscn-fzf() {

    : """Launch VS-Code with a file or folder chosen with fzf"

    builtin cd ~/Documents \
        || return

    command code -n "$( fzf )"
}
