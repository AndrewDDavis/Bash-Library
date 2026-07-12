git-show-toplevel() {

    : """print the top-level directory of the current git repo

     no args expected
    """


    # convert HOME to ~
    git rev-parse --show-toplevel "$@" \
        | sed "s:^${HOME}:~:"
}
