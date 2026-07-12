if [[ $( command top --version 2>/dev/null ) == *procps-ng* ]]
then
    # Linux top (from procps package)
    top-cpu() {

        : """Order display by CPU usage

            Calls top using -o, which orders the display by key (default pid).
        """

        top -o'%CPU' "$@"
    }

    top-sb() {

        : """Prevent top from clobbering the scrollback buffer"""

        tput smcup
        top "$@"
        tput rmcup
    }
fi
