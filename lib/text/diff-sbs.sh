# Side-by-side diff

diff-sbs() {

    # side-by-side diff using -y
    #
    # Usage: diff-sbs <file1> <file2>
    #
    # -t : tabs -> spaces

    diff -yts "$@"
}

diff-sbsw() {

    # side-by-side word diff
    #
    # Usage: diff-sbsw <file1> <file2>
    #
    # - uses overall width of 120 columns

    diff -yts --color=always -W 120 <( fold -s -w46 "$1" ) <( fold -s -w46 "$2" )
}
