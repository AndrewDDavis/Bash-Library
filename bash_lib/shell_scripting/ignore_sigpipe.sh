ignore_sigpipe() {

    # Ignore exit code 141 from command pipes.
    #
    # Usage
    #
    #     ignore_sigpipe $?
    #
    # Returns with code 0 (true) for $1=141, otherwise returns with the value of $1.
    #
    # Notes
    #
    #   - A return status code of 141 usually only occurs when running with
    #     `set -o pipefail`.
    #
    #   - A pipeline returns 141 because a program stopped reading from a pipe before
    #     the writing command was finished. Then the writing command was terminated by
    #     signal 13 (SIGPIPE), and Bash reports status code 128 + 13 = 141.
    #
    #   - See [my answer][^1] for more details.
    #     [^1]: https://unix.stackexchange.com/a/709880/85414
    #
    # Example
    #
    #     yes | head -n1 || ignore_sigpipe $?

    (( $# == 0 )) || [[ $1 == @(-h|--help) ]] \
        && { docsh -TD; return; }

    (( $1 == 141 )) || return $1
}
