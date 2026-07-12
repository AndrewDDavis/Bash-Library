notes-broot() {

    : """Use broot to quickly search for txt notes"

    # TODO:
    # - add options like food, home, etc for starting subdirs
    # - see notesf function for more

    # - get the search started with an argument, or add it into //i
    if notes_fn=$(broot -c '/md.txt$/&/'"$@"'/i' ~/Sync/Documents)
    then
        if [[ -n $notes_fn ]]
        then
            # Also copy to clipboard, quoted
            local notes_fn_q
            notes_fn_q=\"$notes_fn\"

            if [[ -n $(command -v wl-copy) ]]
            then
                wl-copy "$notes_fn_q"
            else
                # Use OSC-52 escape sequence
                # - note, OSC-52 adds a newline, which is annoying
                # - uses OSC-52: https://chromium.googlesource.com/apps/libapps/+/HEAD/nassh/docs/FAQ.md#is-osc-52-aka-clipboard-operations_supported
                local notes_fn_b64
                notes_fn_b64=$(base64 --wrap=0 <<<"$notes_fn_q")
                printf '\e]52;c;%s\a' "$notes_fn_b64"
            fi

            printf '%s\n' "Copied: $notes_fn_q"
        else
            unset notes_fn
        fi
    fi
}
