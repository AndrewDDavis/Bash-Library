duh() {

    : """Print sorted disk usage of a directory tree

    Usage: duh [du-options] [path-root]

    This function prints the disk usage of directories under the specified
    tree, by running the 'du -hSD' command (option details below). If the
    path-root argument is omitted, the current directory is used. The results
    are ordered using 'sort -h'.

    - If the -s (--summarize) option is detected on the command line, the
      -S option is omitted from the du command. This allows command-lines
      like 'duh -s *' to act as intended.

    - To print file sizes as well as directory usage, use '-a' or a glob
      pattern.

    Notable du options:

      -a (--all)
      : write counts for all files, not just directories

      -c (--total)
      : produce a grand total

      -D (--dereference-args)
      : dereference only symlinks that are listed on the command line

      -h (--human-readable)
      : print sizes in human readable format (e.g., 1K 234M 2G)

      -L (--dereference)
      : dereference all symbolic links

      -s (--summarize)
      : display only a total for each argument, not for the files it contains

      -S (--separate-dirs)
      : when printing directory sizes, do not include size of subdirectories

      --time[=...]
      : show last modification time, or others using the argument

      -x (--one-file-system)
      : do not cross file-system boundaries
    """

	[[ $# -eq 1  && $1 == @(-h|--help) ]] &&
    	{ docsh -TD; return; }

    # rudimentary check for -s
    local arg _s
    for arg in "$@"
    do
        [[ $arg == -*s* ]] \
            && _s=1
    done

    local du_args=()
    if [[ -v _s ]]
    then
        du_args+=( -hD )
    else
        du_args+=( -hSD )
    fi

    command du "${du_args[@]}" "$@" \
        | command sort -h
}
