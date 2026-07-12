# Merge files

diff-mrg-ifdef() {

    # merge with ifdef statements marking differences
    #
    # Usage: diff-mrg-ifdef [diff-args]
    #
    # - can leave the #if and #endif statements, and later do
    #   grep -v '^#if' merged.xml | grep -v '^#endif' > clean.xml

    diff -D NEWSTUFF "$@"
}

diff-mrg-quick() {

    # quick merge using diff -u
    #
    # Usage: diff-mrg-quick [diff-args]
    #
    # - this creates a fully unified file, with patch-style diff areas
    # - probably better would be to edit the merge file and use `patch`, as intended

    [[ -e dmq.merge ]] && return 1

    diff -u 999999 "$@" > dmq.merge \
        || return
    $EDITOR dmq.merge
    # edit as desired ...

    # remove leading chars
    sed -i'' 's/^.//' dmq.merge
}

diff-mrg-patch() {

    # patch after using diff -u
    #
    # Usage: diff-mrg-patch [diff-args]
    #
    # - probably better would be to edit the merge file and use `patch`, as intended

    [[ -e dmp.merge ]] && return 1

    diff -u3 "$@" > dmp.merge \
        || return
    $EDITOR dmp.merge
    # edit as desired...

    # remove leading chars
    #sed -i'' 's/^.//' dmp.merge
    echo patch... >&2
}

if [[ -n $( command -v sdiff ) ]]
then
    diff-mrg-sdiff() {

        # sdiff: side-by-side diff merge
        #
        # Usage: diff-mrg-sdiff outfile [sdiff args]
        #
        # - see usage at https://www.jpeek.com/articles/linuxmag/2007-05
        # - hit enter for help
        # - would be nice to make this a function, have the column widths only as large as needed

        #sdiff -o merged.file left.file right.file
        sdiff -w $( tput cols ) -lt --tabsize=4 -o "$@"
    }
fi
