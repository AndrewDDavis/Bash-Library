: """Ignore exit code 141 from command pipes

    Usage

        ignore_sigpipe \$? [n]

    Returns with code 0 (true) when the first argument is 141, otherwise returns
    with the value of the argument.

    Since some programs do not exit 141 on sigpipe, you may optionally supply n,
    representing a different value to test against. Notably, GNU sort exits with
    code 2.

    Notes

      - A return status code of 141 usually only occurs when running with
        \`set -o pipefail\`.

      - A pipeline returns 141 because a program stopped reading from a pipe before
        the writing command was finished. Then the writing command was terminated by
        signal 13 (SIGPIPE), and Bash reports status code 128 + 13 = 141.

      - The program that was writing to the pipe may report an error message such as
        'write failed: Broken pipe'.

      - See my answer for more details:
        https://unix.stackexchange.com/a/709880/85414

    Example

        yes | head -n1 || ignore_sigpipe \$?
"""

ignore_sigpipe() {

    (( $# == 0 )) || [[ $1 == @(-h|--help) ]] \
        && { docsh -TD; return; }

    # exit status code to test
    local _ec=$1
    shift

    # usually sigpipe produces 141, but e.g. sort exits 2
    local -i _n=141
    (( $# == 0 )) \
        || { _n=$1; shift; }


    (( _ec == _n )) || return "$_ec"
}
