zip-info() {

    : """Show zip archive info and file listing

    Usage: zip-info [opts] archive.zip

    Notes

    - Use -v for maximum verbosity.
    - This uses the -m option (medium verbosity), which includes the output of
      -h (headers) and -t (totals). It also adds -z to print the archive
      comment, if any.
    - The only difference with -s (short) output, is that is omits the
      compression ratio column, and with -l (long) is that is prints the
      compressed size instead of ratio.
    """

    [[ $# -eq 0 ||  $1 == @(-h|--help) ]] &&
    	    { docsh -TD; return; }

    zipinfo -mz "$@" \
        | more
}
