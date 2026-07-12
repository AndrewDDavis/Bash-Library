# gedit editor
gedit-adm() (
    [[ $# -eq 0 || $1 =~ ^(-h|--?help)$ ]] && {
        docsh -TD """Edit file(s) as root using gedit
        
        Usage: gedit-adm file1 [file2 ...]
        """
        return
    }
    
    fns=()
    for fn in "$@"
    do
        fns+=( printf 'admin://%s' "$(readlink -f "$fn")" )
    done
    
    gedit "${fns[@]}"
)

