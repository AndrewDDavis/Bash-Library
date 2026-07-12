# dependencies
import_func array_strrepl tree-fromfiles \
    || return

# docsh fd-wrapper
# Find files using user-friendly syntax and defaults
#
# Usage: fd-wrapper [options] [pattern] [path ...]
#
# This function acts as a wrapper to the fd command, which may be called fdfind on
# some systems. The --no-ignore-vcs option is added to the fd command by default,
# and the following additional option is interpreted:
#
# --tree
# : This option shows the matched files in a tree view. This is done by passing
#   the fd output as a null-delimited list to the tree-fromfiles function, which
#   relies on the tree command. The --noreport tree option is also recognized.
#
# The partner file fd-wrapper_env.sh defines an alias of fd to fd-wrapper, as well
# as convenience aliases such as fdtree, fda, fdl, and fdu.
#
# If the path is omitted, the tree under the current directory is searched.
#
# Symlinks are not followed, unless -L (--follow) is used. Mount points in the
# tree are searched, unless --xdev (--one-file-system) is used.
#
# The pattern is interpreted as a regular expression that may match a substring of
# file basenames. The Rust regex engine is used, with syntax similar to 'grep -E'
# or POSIX ERE (refer to <https://docs.rs/regex/1.0.0/regex/#syntax>). The
# following fd options modify the pattern matching behaviour:
#
# -p (--full-path)
# : Match full paths.
#
# -F (--fixed-strings)
# : Treat the pattern as a literal string, but still match as a substring.
#
# -g (--glob)
# : Treat the pattern as a glob. This option also disables substring matching
#   (only full filenames are matched). If combined with --full-path, '**' matches
#   multiple path components.
#
# --and
# : Add additional patterns which must both match a filename. To add alternative
#   (OR) patterns, use syntax like 'abc|def'.
#
# By default, fd uses smart-case matching (i.e. cases-insensitive for lowercase
# patterns). Modify this with -s (--case-sensitive) or -i (--ignore-case).
#
# By default, fd excludes hidden files and directories from the search results
# (i.e. filenames that start with '.'). It also excludes files designated in
# ignore files noted below. To show all possible results, use option -u
# (--unrestricted), which is an alias for -HI. The following options may be used
# to include specific file types:
#
# -H (--hidden)
# : Include hidden files in the search results (i.e. filenames beginning with
#   '.').
#
# -I (--no-ignore)
# : Include files that would be excluded by ignore files. fd recognizes git ignore
#   files at the directory, repository, and global levels: '.gitignore',
#   '.git/info/exclude', and '~/.config/git/ignore'. It also respects directory-
#   level ignore files named '.ignore' and '.fdignore', and a global ignore file
#   at '~/.config/fd/ignore'.
#
#   Refer to the gitignore manpage for the syntax of those files, which is similar
#   to shell globbing that includes the '**' pattern.
#
#   It's generally useful to create a '~/.config/fd/ignore' file that excludes the
#   ignore files themselves, the contents of .git dirs, and other hidden files of
#   little interest.
#
# --no-ignore-vcs
# : Show results that would be excluded by the git ignore files, but respect the
#   fd-specific ones. This option is added automatically by fd-wrapper. Use
#   --ignore-vcs to override the function default.
#
# The search results may be filtered using these options:
#
# -E (--exclude)
# : Excluded files using a glob pattern. E.g. '--exclude \*.pyc'.
#
# -t (--type)
# : Include only specific file type(s), which accepts d for dirs, f for files, l
#   for symlinks, x for executable files, or e for empty files. E.g. '-te -td' for
#   empty dirs.
#
# -e (--extension)
# : Include only specific file extension(s). Repeated use of this option matches
#   multiple possible extensions, e.g. '-e .sh -e .bash'. The dot may be omitted
#   from the pattern, but will be added internally. To match a filename suffix
#   that is not preceded by a dot, use a regular pattern such as '_env.sh$'. To
#   match files with no extension, use the regex pattern '^[^.]+$'.
#
# --newer (--changed-after, --change-newer-than, --changed-within)
# --older (--changed-before, --change-older-than)
# : These filters accept a duration (e.g. 10h, 1d, 35min, 2weeks) or a specific
#   date or time (e.g. YYYY-MM-DD).
#
# -S (--size)
# : Filter based on file size, as <+-><NUM><UNIT>, e.g. '-5k'.
#
# -o (--owner)
# : Filter base on owner, as [user][:group].
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

fd-wrapper() {

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
