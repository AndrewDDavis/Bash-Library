: """Check whether path is already part of the PATH variable

    Usage: path_has <path> ...

    The function returns False if any of the paths are not on the PATH.
"""

path_has() {

    [[ $# -eq 0  || $1 == @(-h|--help) ]] \
        && { docsh -DT; return; }

    local pp _rs=0

    for pp in "$@"
    do
        # the specificity of this pattern is needed for paths like '/bin'.
        case "$PATH" in
            ( "$pp" | "$pp:"* | *":$pp" | *":$pp:"* )
                continue ;;
            ( * )
                _rs=1 ;;
        esac
    done

    return $_rs
}
