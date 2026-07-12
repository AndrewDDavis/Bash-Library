diff-qs() {

    # just report changed files
    diff -qs "$@"
}

diff-u() {

    # Show a patch diff with colour in a pager
    #
    # Usage: diff-u [diff-opts] file1 file2
    #
    # diff options in effect:
    #
    #  -u : patch (3 unified context lines around changes)
    #  -s : report identical files

    diff -us --color=always "$@" | less -FR
}

[[ -n $( command -v diffr ) ]] && {

    diff-hldiffr () {

        # use diffr to processes the output of 'diff -u' to highlight words
        # - this is pretty good
        diff -u "$@" \
            | diffr
    }
}

# diff-highlight
# - this package, which ships with git, also tries to postprocess diff output to
#   highlight words, but isn't very good; see /usr/share/doc/git/contrib/diff-highlight/README
#diff-hl () {
#
#    git diff --no-index --color "$@" |
#        perl /usr/share/doc/git/contrib/diff-highlight/diff-highlight
#}

diff-g() {
    # git diff
    git diff --minimal --no-index "$@"
}

diff-gw() {

    # Word-diff using git diff
    #
    # - NB, plain mode uses color too
    # - NB, anything the in word-diff-regex is considered whitespace, and
    #   ignored(!) for the purposes of finding differences. So, probably better to
    #   stick with the default, rather than e.g.:
    #   --word-diff-regex='[^[:punct:][:space:]]+'

    git diff --no-index --minimal --word-diff "$@"
}

[[ -n $( command -v dwdiff ) ]] && {

    diff-dw() {

        # dwdiff is a better tool, allows punct as word boundary; still shares the
        # annoyance of sometimes introducing a space into the output.

        dwdiff --color "$@"
    }
}
