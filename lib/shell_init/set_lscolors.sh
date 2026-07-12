# deps
import_func vrb_msg trap-err \
    || return

# docs
: """Set LS_COLORS from dircolors defaults and custom config

    Usage: set_lscolors [options]

    This function facilitates setting custom colours for GNU ls, tree, and others that
    use the LS_COLORS environment variable.

    Options

      -c
      : Disable check of dircolors default database. Usually, set_lscolors checks
        whether the defaults have changed since the default config file was last written
        to disk. It may be desirable to disable the check from the command call in
        ~/.bashrc, but it is recommended to let the check run occasionally, particularly
        after an update to the coreutils package.

      -p or -P
      : Instead of setting LS_COLORS, print the default (-p) or customized (-P) settings
        in colour, to show what the colour settings look like in your shell.

    Operation

    On the initial run, set_lscolors creates config files in '~/.config/lscolors/' (or
    XDG_CONFIG_HOME if set). An empty \`dircolors.custom\` file will be created to hold
    custom colour settings. The default dircolors database is written as
    \`dircolours.defaults\`, using the \`dircolors -p\` command.

    Refer to the comments in dircolours.defaults and the dir_colors manpage to
    understand the meaning of the lines. Note that glob patterns may be used in TERM or
    COLORTERM entries, but not for matching file extensions. The most likely lines of
    interest are those for the basic file types, such as the lines starting with DIR,
    LINK, or EXEC, or the lines for specific file extensions, such as .jpg, .mp3, or
    .bak.

    To customize the configuration, copy relevant lines from dircolors.defaults into
    dircolors.custom and modify them.

    After adding changes to dircolors.custom, run \`set_lscolors\` to enact the changes
    in the current shell session. This generates a dircolours.custom file, and writes
    the resulting settings to the LS_COLORS variable.

    To make the changes permanent, add the set_lscolors function call to your
    '~/.bashrc', '~/.zshrc', or the relevant startup file for your shell. On subsequent
    runs, set_lscolors only generates a new dircolours.combined file when the
    dircolours.custom file is updated.

    Background

      - The LS_COLORS environment variable defines the colours used in the output of
        GNU's ls command. This sets the colours of file-names based on file type,
        extension, or permissions.

      - Typically, LS_COLORS is set in a shell init file using the output of the
        'dircolors -b' command from the GNU coreutils package. The command outputs a
        series of colour strings to match against file extensions, separated by ':', and
        includes the syntax to export the LS_COLORS variable. Without a file argument,
        dircolors emits the colors from a precompiled database.

      - For more info, refer to the man-pages for 'dir_colors', 'dircolors', and 'ls'.
        Note the comments in 'dir_colors' indicating that GNU dircolors ignores any
        /etc/DIR_COLORS or ~/.dir_colors files, and several options.

    Other Notes

      - While it may seem like a bad idea to run dircolors every time you start a new
        shell, in my testing it took < 7 ms to run.

      - Since only the dircolors.custom file should be edited, the write permissions of
        the dircolors.defaults and dircolors.combined files are removed.

      - Dircolors file format:

          + Important lines start with an uppercase word or a pattern, then a space and
            another word.
          + Patterns start with '.' or '*'.
          + There are no tabs or double spaces.
          + Comments start with #.
          + Some (comment) lines have leading blanks.

      - Using 256-color sequences:

          + A useful visual of the colours: [link](https://user-images.githubusercontent.com/1482942/93023823-46a6ba80-f5e1-11ea-9ea3-6a3c757704f4.png)
          + The 'tree' command uses LS_COLORS, and doesn't work well when using the
            '38:5:x' syntax for 8-bit colours. It doesn't use colour, and prints an 'm'
            before every entry in the tree. The alternative is to use semicolons, as
            '38;5;x'. In practice, this appears to be the best syntax to use, as it's
            supported by tree and ls.
"""

set_lscolors() {

    [[ $# -gt 0  && $1 == @(-h|--help) ]] \
        && { docsh -TD; return; }

    trap '
        trap-err $?
        return
    ' ERR

    trap '
        unset -f _parse_args _chk_defaults _strip_dcfile \
            _merge_dcfiles _print_clrs
        trap - err return
    ' RETURN

    _parse_args() {

        local flag OPTARG OPTIND=1
        while getopts 'cpP' flag
        do
            case $flag in
                ( c ) _c=0 ;;
                ( p ) _p=1 ;;
                ( P ) _p=2 ;;
                ( * ) return 2 ;;
            esac
        done
        shift $(( OPTIND-1 ))

        (( $# == 0 )) \
            || { err_msg 5 "unexpected args: '$*'"; return; }

        dc_cmd=$( builtin type -P dircolors ) \
            || { err_msg 9 "dircolors command not found"; return; }

        grep_cmd=$( builtin type -P grep ) \
            || { err_msg 9 "grep command not found"; return; }

        # config directory
        local _lscdir=${XDG_CONFIG_HOME:-~/.config}/lscolors

        [[ -e $_lscdir ]] \
            || { /bin/mkdir -p "$_lscdir" || return; }

        def_fn=${_lscdir}/dircolors.defaults
        cust_fn=${_lscdir}/dircolors.custom
        comb_fn=${_lscdir}/dircolors.combined
    }

    _chk_defaults() {

        trap 'return' ERR
        trap 'trap - return err' RETURN

        if [[ ! -e $def_fn ]]
        then
            vrb_msg 2 "Creating defaults file at '${def_fn}'."
            "$dc_cmd" -p > "$def_fn"
            /bin/chmod a-w "$def_fn"

        elif (( _c ))
        then
            # check current defaults against existing file
            local _chk_fn
            _chk_fn=$( mktemp -t lscolors_tmp.XXXXX )

            "$dc_cmd" -p > "$_chk_fn"

            if diff -q "$_chk_fn" "$def_fn" &> /dev/null
            then
                vrb_msg 2 "No changes detected in dircolors defaults."
                /bin/rm "$_chk_fn"

            else
                vrb_msg 1 \
                    "Change detected in dircolors defaults."  \
                    "New defaults written to '${def_fn/#"$HOME"/\~}.new'." \
                    "View the changes:" \
                    "    diff -u ${def_fn/#"$HOME"/\~}{,.new}"  \
                    "Start using the new defaults:" \
                    "    /bin/mv -f ${def_fn/#"$HOME"/\~}{.new,}"

                /bin/mv -f "$_chk_fn" "$def_fn".new
                /bin/chmod a-w "$def_fn".new
            fi
        fi
    }

    _strip_dcfile() {

        # Reads from passed filename, edits lines as noted below, writes to stdout.
        sed -E '
            /^[ \t]*$/ d        # delete empty or blank lines
            /^[ \t]*#/ d        # delete comment lines
            s/^[ \t]+//         # strip leading blanks
            s/[ \t]+$//         # strip trailing blanks
            s/[ \t]+#.*$//      # strip trailing comments
            s/[ \t][ \t]+/ /    # squash multiple blanks into 1 space
        ' "$1"
    }

    _merge_dcfiles() {

        if [[ ! -e $cust_fn ]]
        then
            # no custom settings, nothing to merge
            printf >"$cust_fn" '%s\n' \
                "# Colour customizations for the LS_COLORS variable" \
                "# Refer to 'set_lscolors -h' for info."

            /bin/rm -f "$comb_fn"
            _strip_dcfile "$def_fn" > "$comb_fn"
            /bin/chmod a-w "$comb_fn"

        elif [[ ! -s $comb_fn
            || "$cust_fn" -nt "$comb_fn" ]]
        then
            # custom file has been updated, create new combined file
            # - merge defaults and custom, ensuring custom has priority

            # read defaults lines into memory as arrays
            # - this will form the basis of the "combined" database file
            # - uses process substitution to create a fifo, then reads it in to stdin
            # - considered using an associative array instead of 2 indexed ones, but
            #   the retrieval is random and I wanted to be able to write it out in
            #   the original order.
            local -a keys clrs
            local _key _clr i=1
            while read -r _key _clr
            do
                keys[i]=$_key
                clrs[i]=$_clr
                (( i++ ))

            done < <( _strip_dcfile "$def_fn" )

            # loop line-by-line through custom config file
            # - edit the values from defaults, or add new lines
            # - the custom file is stripped of blank lines, comments, and leading
            #   whitespace on reading
            while read -r _key _clr
            do
                if i=$( "$grep_cmd" -Fxm1 -n "$_key" < <( printf '%s\n' "${keys[@]}" ) )
                then
                    # custom key overrides defaults entry
                    # - get 1-based index from 'grep -n' (don't use grep -z; null-byte warning)
                    i=${i%%:*}
                    clrs[i]=$_clr

                else
                    # no match from defaults; add new entry
                    keys+=( "$_key" )
                    clrs+=( "$_clr" )
                fi

            done < <( _strip_dcfile "$cust_fn" )

            # write out combined database
            /bin/rm -f "$comb_fn"

            for i in "${!keys[@]}"
            do
                printf '%s %s\n' "${keys[i]}" "${clrs[i]}" >> "$comb_fn"
            done
            /bin/chmod a-w "$comb_fn"
        fi
    }

    _print_clrs() {

        if (( _p == 1 ))
        then
            "$dc_cmd" --print-ls-colors "$def_fn"

        elif (( _p == 2 ))
        then
            "$dc_cmd" --print-ls-colors "$comb_fn"
        fi
    }

    # defaults and CLI args
    local dc_cmd grep_cmd def_fn cust_fn comb_fn
    local _c=1 _p=0 _verb=1
    _parse_args "$@"

    # create or check defaults file
    _chk_defaults

    # create combined file
    _merge_dcfiles

    if (( _p ))
    then
        # print colours
        _print_clrs

    else
        # Set LS_COLORS and export it in the shell
        # - extract the string from dircolors cmd; I really don't like eval
        declare -gx LS_COLORS
        LS_COLORS=$(
            "$dc_cmd" -b "$comb_fn" \
                | sed -E "s/^LS_COLORS='(.*):';\$/\1/; q"
        )
    fi
}

# TODO
# - consider setting up LSCOLORS for BSD ls
# - consider GREP_COLORS
# - make some ChromeOS terminal colours more like vscode ones, especially cyan
# - add an 'unset' or 'none' option, to delete a setting
# - also consider NNN colours, see man page, NNN_COLORS and NNN_FCOLORS
# - there are good ideas for how to structure a function like this in [this repo][1]
#   such as using the env var 'export COLORS_DEFINED="yes"'
#   [1]: https://github.com/Sitwon/bash_patterns/blob/master/colors.sh
