sort-noansi() {

    [[ $# -gt 0  && $1 == @(-h|--help) ]] && {

        : """Sort a list while ignoring ANSI escape sequences

            Usage: sort-noansi [sort-opts] <<< \"input\"

            Awk is used to make a duplicate of the first field of each input line on
            STDIN, with any ANSI bits stripped out. The fields are created by splitting
            a line by runs of whitespace, with leading and trailing whitespace ignored
            (regex /[ \t\n]+/).

            Then the sort command is used to sort the text, using any options provided.

            Finally, the cut command is used to strip out the added field and return the
            sorted lines.
        """
        docsh -TD
        return
    }

    # Use awk and sort
    # - from https://unix.stackexchange.com/a/157971/85414
    local _filt='
        {
            s = $1
            gsub(/\033\[[ -?]*[@-~]/, "", s)
            print s "\t" $0
        }
    '

    awk "$_filt" \
        | sort "$@" \
        | cut -f 2-
}
