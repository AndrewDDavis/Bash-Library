find-to-array() {
    # alias for discoverability
    array_from_find "$@"
}

array_from_find() {

    : """Run find to populate an array with file paths

        Usage: array_from_find <array-name> [find-arguments] ...

        This function uses \`find\` to match file paths, and the matches are written to
        the designated array variable. All arguments after the array name are passed to
        find. If no search starting point directories are provided in the arguments,
        find will use '.', as usual.

        By default, symlinks are not followed (dereferenced) by find. Refer to the
        pre-options '-L' and '-H' to modify this behaviour.

        Typically, the find arguments include -name, -path, or -regex to provide
        a pattern to match against file paths. Other commonly used options include
        -maxdepth, -type, -mtime, and -readable.

        When using -name or -path to match glob patterns, the '*' and '?' wildcard
        characters, neither '.' nor '/' are treated specially. That is, they match both
        filenames with leading dots (hidden files), and path separators. This can be
        surprising compared to shell globbing, e.g. -path './*.txt' would match the
        file './d/.f.txt'.

        When using -regex to match file paths with a regular expression pattern,
        Find's default syntax is almost identical to emacs, and similar to basic posix
        regular expressions. The online findutils documentation has an excellent
        [comparison of regex syntax across tools][1]. To use extended regular
        expressions as in \`egrep\`, use -regextype posix-extended.

        This function adds -print0 to the find arguments to generate null-terminated
        strings and prevent file paths with newlines from causing problems. This will
        be omitted if -print0 or -printf is detected in the arguments. When using
        -printf, be sure to terminate the format string with null ('\0'). E.g., to
        print file paths without printing their search root, use -printf '%P\0'.

        It is recommended to use your own -print0 argument to prevent unexpected
        results when constructing a logical expression, such as the common method of
        excluding a directory: -name skip_this -prune -o \\( -type f,l -print0 \\).
        Similarly, exclude hidden files with -name '.?*' -prune -o ....

        The return status is 0 (true) for at least one match, 1 (false) for no matches,
        or > 1 for an error.

        [1]: https://www.gnu.org/software/findutils/manual/html_node/find_html/Regular-Expressions.html
    """

    [[ $# -eq 0  || $1 == @(-h|--help) ]] &&
        { docsh -TD; return; }

    local find_pth find_cmd
    find_pth=$( builtin type -P find ) \
        || return 6
    find_cmd=( "$find_pth" )

    # defaults and posn'l args
    local -n __res_arr__=${1:?missing array name}
    shift

    find_cmd+=( "$@" )
    shift $#

    # check whether -print0 or printf were used
    array_match find_cmd '-print0|-printf' ||
        find_cmd+=( -print0 )

    __res_arr__=()
    {
        mapfile -d '' __res_arr__ < \
            <( "${find_cmd[@]}" )
    } \
        || return

    # return status
    [[ -v __res_arr__[*] ]]
    return

    # older Bash loop code:
    # local fn
    # while IFS= read -r -d '' fn
    # do
    #     # printf '<%s>\n' "$fn"
    #     __res_arr__+=( "$fn" )
    # done < \
    #     <( "${find_cmd[@]}" )
}
