if [[ -n $( command -v dos2unix ) ]]
then
    ls-crlf() {

        : """Print files with dos line endings

        Usage: ls-crlf [glob ...]

        The glob or extended glob will be used to match files to check (e.g. '**').
        """
        [[ $# -eq 0 || $1 == -h ]] &&
            { docsh -TD; return; }

        # -i 'c' causes d2u to only print files that would be converted
        # -q suppresses messags and warnings
        dos2unix -q -ic "$@"

        # could make a -R version:
        # find . -name '*.txt' -print0 |xargs -0 dos2unix
        # -L . -type f
    }
fi

grep-crlf() {

    : """Find text files with DOS line-endings

    Usage: grep-crlf [file or dir ...]

    This function recursively searches for text files with DOS line-endings, by calling
    'grep -IRl' with a pattern matching the carriage return character at the end of a
    line (i.e. CRLF). If no files or directories are specified, the working directory is
    searched.

    To visualize the CR characters (as ^M), you may pipe the output to 'cat -v'.
    """
    [[ $# -eq 0 || $1 == -h ]] &&
        { docsh -TD; return; }

    grep -IURl $'\r$' "$@"
}
