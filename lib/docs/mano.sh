# reformat and open man pages in other apps
if [[ ( -n ${BROWSER:-} || -n $( command -v x-www-browser ) ) &&
      ( -n ${WAYLAND_DISPLAY:-} || -n ${DISPLAY:-} ) ]]
then
    mano() {
        # Open man pages in the browser in Linux GUI environment
        local tmpfile

        # must pass a file in HOME for garcon-url-handler on ChromeOS
        [[ -d ~/Downloads ]] && tmpfile=$(mktemp -p ~/Downloads "$1".XXXXX.txt)

        MANWIDTH=100 MANPAGER='col -bx' man "$1" > "$tmpfile"
        x-www-browser "$tmpfile"

        # wait for load, then clean up
        sh -c "sleep 5; /bin/rm \"$tmpfile\"" &

        # lacks width setting:
        # groffer --text man:zshoptions | col -bx > zshoptions.txt
    }

    manoh() {
        # Open man pages in the browser on ChromeOS
        # NB ChromeOS can't access the /tmp dir
        # - groffer can format text into arbitrary formats, html, pdf, etc.
        GROFF_TMPDIR=~/Downloads  \
            groffer --www --viewer garcon-url-handler  \
                    -P '-s' -P '6' -P -D/home/andrew/Downloads -P -i200  \
                    man:"$1"
    }

elif [[ $(uname -s) == Darwin ]]
then
    mano() {
        # Open man pages in the browser on macOS
        MANWIDTH=100 MANPAGER='col -bx' man "$@" \
            | open -f -a Google\ Chrome
    }
fi
