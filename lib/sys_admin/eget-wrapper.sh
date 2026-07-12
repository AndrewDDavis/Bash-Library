# Eget: Easily install prebuilt binaries from GitHub

# TODO:
# - check command, to see if an update is available
# - see TODO below

eget-wrapper() {

    : """Wrapper for common operations using eget

        Usage

          init <name> <target>
            : Initialize directory for new software at /usr/local/share/<name>, and add an
              entry to ~/.config/eget/eget.toml. The target can be a URL or github dev and
              project, like zyedidia/eget.

          ug <name> (TODO: NOT FINISHED)
            : Install or upgrade program. Downloads a new versioned binary, installs it into
              /usr/local/bin, and updates the program's symlink. If name is 'all', runs the
              -D operation to download all software listed in the config file. (?)

        For all eget options, see 'eget --help', or https://github.com/zyedidia/eget.
        Briefly:

        ...
    """

    [[ $# -eq 0  || $1 == @(-h|--help) ]] &&
        { docsh -TD; return; }

    # eget config file
    local eget_conf_fn=~/.config/eget/eget.toml

    [[ -e $eget_conf_fn ]] ||
        { err_msg 2 "config file not found: '$eget_conf_fn'"; return; }

    # parse args
    local cmd sw_name sw_dir url_fn
    cmd=$1
    sw_name=$2
    shift 2

    sw_dir=/usr/local/share/$sw_name
    url_fn=${sw_dir}/eget_url.txt

    case $cmd in
        ( init )
            url=$1

            [[ ! -e $url_fn ]] ||
                { err_msg 6 "url file exists: '$url_fn'"; return; }

            # create dir and URL file
            /bin/mkdir -p "$sw_dir"

            printf '%s\n' "$url" > "$url_fn"

            ! grep -q "$url" "$eget_conf_fn" \
                || { err_msg 7 "target '$url' entry exists in $eget_conf_fn"; return; }

            printf '\n["%s"]\n' "$url" >> "$eget_conf_fn"
            printf '    target = "%s"\n' "$sw_dir" >> "$eget_conf_fn"
        ;;
        ( ug )
            builtin cd "$sw_dir"
            eget -d $( < eget_url.txt )

            echo "needs implementation"
            # select system?
            # rename
            # move to bin
        ;;
    esac
}
