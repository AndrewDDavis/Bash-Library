# deps
import_func physpath array_from_find \
    || return

find-linksto() {

    : """Print symlinks pointing to a directory or file

    Usage: find-linksto <pattern> <search-root>

    The second argument is used as the search-root for a find commmand that matches
    symlinks within the tree.

    The first argument is used as a regex pattern (POSIX ERE) to match paths using
    Bash's regular expression matching tool.

    Examples

      # find links to, or into, the Config-Sync project directory
      find-linksto '/Config-Sync' ~/

      # find all links within the user's .local directory
      find-linksto . ~/.local
    """

    [[ $# -ne 2  || $1 == @(-h|--help) ]] \
        && { docsh -TD; return; }

    # args
    local pth_root ptn
    ptn=$1
    pth_root=$2
    shift $#

    # More conventional method can use readlink (Linux-only) and grep
    # command find "$pth_root" -type l -printf '%p -> ' -exec readlink -f {} \; \
    #     | command grep -E "$ptn"

    # TODO:
    #
    # - Find out why the below is so slow compared to the conventional method. It's not
    #   because of == vs =~, that makes very little difference.
    #
    #   The below is cross-platform, relies on shell only, but about double the execution
    #   time(!), even just by putting the readlink and grep commands in for physpath
    #   and [[ ... =~ ... ]].
    #
    #   What's more, using the above pipe is 1/4 the time of the code below.

    # use 'find -type l' to print both intact and broken symlinks
    local fnd_out=()
    array_from_find fnd_out "$pth_root" -type l \
        || return

    (( ${#fnd_out[*]} > 0 )) \
        || { printf >&2 '%s\n' 'No matches.'; return; }

    local fn pp
    for fn in "${fnd_out[@]}"
    do
        if ! pp=$( physpath "$fn" 2>&1 )
        then
            # - physpath returns with code 1 on broken symlinks, and we can get the
            #   symlink target from the error message
            local rgx=" is a broken symlink to '(.*)'\$"
            [[ $pp =~ $rgx ]]
            pp="(broken) ${BASH_REMATCH[1]}"
        fi

        if [[ ${pp#'(broken) '} =~ $ptn ]]
        then
            printf '%s -> %s\n' "$fn" "$pp"
        fi
    done
}
