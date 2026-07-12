# dependencies
import_func std-args array_match \
    || return

: """Search for files matching pattern, display as tree

    Usage: tree-match [options] [pattern [[--] dir1 ...]]

    The tree command is used to match files and directories under the specified
    root paths ('.' by default). This function uses the --filesfirst option, so
    that files are listed before directories. Otherwise, it operates just like
    calling the tree command directly, unless the command-line includes a pattern.

    If no pattern is passed, all files and directories are printed, subject to the
    settings of -a and --gitignore. The pattern matching occurs as follows:

      - The pattern is passed to tree using the -P option, which has syntax similar
        to shell globbing using the extglob option. This allows alternative patterns
        to be matched using '|'.

      - Directories are matched, as well as filenames (--matchdirs). A pattern
        ending in '/' matches only directories.

      - Directories that don't match the pattern, and don't contain matching files,
        are omitted from the listing (--prune).

      - The matching is case insensitive (--ignore-case).

      - If further -P options are issued, files that match any of the patterns are
        printed.

      - Contrary to what might be expected from the manpage, the '**/' pattern
        should not be used with tree -P or -I. The patterns should be simple
        basename-matching patterns, and not include any '/' except possibly as the
        last character, to match directories. This is per the response from the dev
        on my [bug report](https://github.com/Old-Man-Programmer/tree/issues/17).

        Another minor inconcistency: when a directory is matched directly, e.g.
        because it resides in the search root, or the pattern starts with '**/',
        its contents are listed. Otherwise, only the directory name is printed.

    Other notable tree options (refer to the tree manpage for a full list):

      -a
      : match hidden files, like 'ls -A'. Without this, no hidden files are matched,
        even with a pattern like '.*'. When this option is passed, tree-match adds
        the arguments -I '.git/' to exclude git directories and their contents.

      -d
      : print only directories

      -D
      : print dates

      -l
      : follow symbolic links if they point to directories

      -L
      : max depth of tree listing (search root = 1)

      -I <pat>
      : exclude files matching pattern. A match to -I trumps a match to -P.

      --noreport
      : omit the file and directory report at the end of the listing
"""

tree-match() {

    [[ $# -eq 0  || $1 == @(-h|--help) ]] \
        && { docsh -TD; return; }

    # parse args for tree
    # shellcheck disable=SC2034
    local so lo opt_arr=() posarg_arr=() _stdopts=()
    # - short and long opts that need args
    so='LPIoHT'
    lo='gitfile infofile charset filelimit timefmt sort hintro houtro scheme authority'

    std-args opt_arr posarg_arr "$so" "$lo" -- "$@"

    # - inspect results
    #   declare -p opt_arr posarg_arr _stdopts
    # - e.g. for args:
    #   args=([0]="-dL4" [1]="-P" [2]="file*" [3]="--gitfile" [4]="foo" [5]="--prune" [6]="posarg" [7]="--opt")
    # - std-args produces:
    #   opt_arr=([0]="-dL4" [1]="-P" [2]="file*" [3]="--gitfile" [4]="foo" [5]="--prune" [7]="--opt")
    #   posarg_arr=([6]="posarg")
    #   _stdopts=([0]="-d" [1]="-L4" [2]="-Pfile*" [3]="--gitfile=foo" [4]="--prune" [5]="--opt")

    # pattern
    local k ptn_args=()
    if [[ -v posarg_arr[*] ]]
    then
        # find first valid index
        for k in "${!posarg_arr[@]}"; do break; done

        ptn_args+=( --ignore-case --matchdirs --prune )
        ptn_args+=( -P "${posarg_arr[k]}" )
        unset 'posarg_arr[k]'
    fi
    # NB, any remaining positional args should be directories, possibly preceded by '--'

    # ignore .git dirs
    if array_match -F -- _stdopts '-a'
    then
        ptn_args+=( -I '.git/' )
    fi

    local tree_cmd
    tree_cmd=( "$( builtin type -P tree )" ) \
        || return 9

    tree_cmd+=( --filesfirst )

    "${tree_cmd[@]}" "${opt_arr[@]}" "${ptn_args[@]}" "${posarg_arr[@]}"
}
