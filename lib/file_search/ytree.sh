[[ -n $( command -v ytree ) ]] && {

    # ytree: classic TUI file manager
    yt() {

        : """wrapper function to run ytree, then cd on exit

            Usage: ytree [archive file|directory]

            - exit with ^Q
        """

        local yt_file yt_cmd

        # designate temp file and ensure clean-up
        trap '
            [[ -n ${yt_file-} ]] &&
                /bin/rm -f "$yt_file"
        ' RETURN

        /bin/mkdir -p ~/.cache
        yt_file=~/.cache/ytree-$$.chdir

        printf '%s\n' "cd $PWD" > "$yt_file"

        if command ytree "$@"
        then
            yt_cmd=$( < "$yt_file" )
            eval "$yt_cmd"

        else
            return $?
        fi
    }
}

