# aliases are also defined in the env/ dir
import_func array_strrepl tree-fromfiles \
    || return

fd-wrapper() {

    # Find variant with user-friendly syntax and defaults
    #
    # Usage: fd-wrapper [options] [pattern] [path ...]
    #
    # This function matches filenames using the fd command, which may actually be called
    # fdfind on some systems. The --no-ignore-vcs option is added by default. This
    # function recognizes the --tree option (details below), but otherwise operates just
    # like calling the fd command directly.
    #
    #   --tree
    #   : This option shows the matched files in a tree view. This is done by passing the
    #     fd output as a null-delimited list to the tree-fromfiles function, which relies
    #     on the tree command. The --noreport tree option is also recognized.
    #
    # Pattern matching occurs according to the following behaviour:
    #
    #   - If the path is omitted, the tree under the current directory is searched.
    #     Symlinks are not followed, unless -L (--follow) is used. Mount points in the
    #     tree are searched, unless --xdev (--one-file-system) is used.
    #
    #   - The pattern is interpreted as a regular expression that may match a substring
    #     of file basenames. The Rust regex engine is used, with syntax similar to
    #     'grep -E' or POSIX ERE (<https://docs.rs/regex/1.0.0/regex/#syntax>).
    #
    #       + Use -p (--full-path) to match full paths.
    #
    #       + Use -F (--fixed-strings) to treat the pattern as a literal string, but
    #         still match as a substring.
    #
    #       + Use -g (--glob) for glob pattern matching. This option also disables
    #         substring matching (exact filenames are matched). If combined with
    #         --full-path, '**' matches multiple path components.
    #
    #       + Use --and to add additional patterns which must both match a filename. To
    #         add alternative (OR) patterns, use syntax like 'abc|def'.
    #
    #   - Smart-case matching is employed (cases-insensitive for lowercase patterns).
    #
    #       + Modify this with -s (--case-sensitive) or -i (--ignore-case).
    #
    #   - By default, fd excludes hidden files (filenames that start with '.'), as well
    #     as other ignored files noted below.
    #
    #       + Use -H (--hidden) to show hidden files. Use -I (--no-ignore) to disable all
    #         ignore files (i.e. show more results). Option -u (--unrestricted) is an
    #         alias for -HI.
    #
    #       + By default, fd respects git-ignore files at the directory, repository, and
    #         global levels: '.gitignore', '.git/info/exclude', and '~/.config/git/ignore'.
    #         It also respects directory-level files named '.ignore' and '.fdignore', and
    #         a global ignore file at '~/.config/fd/ignore'.
    #
    #         Refer to the gitignore manpage for the syntax of those files, which is
    #         roughly shell globbing that includes the '**' pattern.
    #
    #       + This function adds the --no-ignore-vcs option to the command line. This
    #         shows results that would be excluded by the git-ignore files, but still
    #         respects the fd-specific ones. Use --ignore-vcs to override the function
    #         default.
    #
    #       + It's generally useful to create a '~/.config/fd/ignore' file that excludes
    #         the ignore files themselves, the contents of .git dirs, and other hidden
    #         files of little interest.
    #
    #   - The search results may be filtered using these options:
    #
    #       + -E (--exclude), which takes a glob pattern.
    #
    #       + -t (--type), which accepts d for dirs, f for files, l for symlinks, x for
    #         executable files, or e for empty files. E.g. '-te -td' for empty dirs.
    #
    #       + -e (--extension), to filter by file extension. To match files with no
    #         extension, use the regex pattern '^[^.]+$'.
    #
    #       + Time-based options, such as --newer, --older, --changed-within,
    #         --changed-after, --changed-before, which take a duration (e.g. 10h, 1d,
    #         35min) or a specific date or time (e.g. YYYY-MM-DD).
    #
    #       + Other properties such as -S (--size) and -o (--owner) [user][:group].
    #
    # The output from fd and tree is colorized using LS_COLORS, and may be modified by
    # these options:
    #
    #   - Use -l (--list-details) to print a detailed listing, like 'ls -l'.
    #
    #   - Use -0, (--print0) to print a null character between search results, rather
    #     than a newline.
    #
    #   - Use --format for custom output.
    #
    # Use -x (--exec) command [args...] to execute a command for each result, using
    # parallelized search and execution. To execute the command once, with all results
    # as arguments, use -X (--exec-batch).
    #
    # Examples
    #
    #   - Match all files in a directory:
    #
    #     fd -HI . dir/
    #
    #   - Equivalent to \"find * -name '*.txt'\":
    #
    #     fd -e .txt
    #
    #   - Show the disk usage of all Trash, .Trash, and .Trash-1000 folders:
    #
    #     fd -H '^(\\.)?Trash(-[0-9]+)?' ~/ \\
    #         -X du -hsc | sort -h

    # fd or fdfind command path and default args
    local fd_cmd
    fd_cmd=( "$( builtin type -P fd )" ) \
        || fd_cmd=( "$( builtin type -P fdfind )" ) \
            || return 9

    fd_cmd+=( --no-ignore-vcs )

    # bare fd command with no pattern is valid
    if (( $# == 0 ))
    then
        "${fd_cmd[@]}"
        return

    elif [[ ${1-} == @(-h|--help) ]]
    then
        docsh -TD
        return
    fi

    # args to array
    local fd_args
    fd_args=( "$@" )
    shift $#

    # parse args
    # - NB, array_strrepl returns T/F for match, then deletes the element when
    #   called with no replacement string.
    local _tree _norpt
    array_strrepl fd_args '--tree' \
        && _tree=1

    array_strrepl fd_args '--noreport' \
        && _norpt=1

    if [[ -v _tree ]]
    then
        # pass file list to tree
        tree-fromfiles ${_norpt:+"--noreport"} < <( "${fd_cmd[@]}" --print0 "${fd_args[@]}" )

    else
        # typical fd command
        "${fd_cmd[@]}" "${fd_args[@]}"
    fi
}
