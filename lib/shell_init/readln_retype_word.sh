readln_retype_word() {

    : """While editing a line using Readline, re-type the previous word

        If issued an argument in the Readline way (e.g. alt-2), the specified word
        will be retyped instead of the last one, where 1 is the last word, 2 is the
        second-last, etc.
    """

    local word words c=0 w=1

    # collect arg if any
    [[ -v READLINE_ARGUMENT ]] &&
        w=$READLINE_ARGUMENT

    # split the current command line into words
    str_to_words words "$READLINE_LINE" ||
        return

    # sanity
    [[ $w -le ${#words[@]} ]] ||
        { echo >&2 "bad argument: only ${#words[@]} words"; return; }

    [[ $READLINE_LINE == *[[:blank:]] ]] || {

        # add space to the existing line
        READLINE_LINE+=' '
        (( c += 1 ))
    }

    # word specified from the end
    (( w *= -1 ))
    word=${words[${w}]}

    # trim a trailing space character from the word, if applicable
    word=${word%[[:blank:]]}

    # duplicate the word
    READLINE_LINE+="$word"

    # place the cursor
    (( c += ${#word} ))
    (( READLINE_POINT += $c ))
}
