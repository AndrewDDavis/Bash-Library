
# TODO:
# - check this answer for ideas: https://askubuntu.com/a/476705/52041
# - also this for tmux: https://unix.stackexchange.com/a/608335/85414
#
# other potentially useful ideas
#
# check for X
# [[ -z ${DISPLAY} && -z ${WAYLAND_DISPLAY} ]]
#
# check tty
# - virtual term emulators typically use /dev/pts/... on Linux
#
# As a last resort, could use a hash of the machine ID to identify the particular
# host we're running on; see https://man.archlinux.org/man/sd_id128_get_machine_app_specific.3.en

term_detect() {

    [[ ${1-} == @(-h|--help) ]] && {

        : """Set environment variables based on the current terminal emulator

        This function attempts to detect the current terminal emulator, and set the
        TERM_PROGRAM environment variable if it is not already set (e.g. by Apple
        Terminal, VS-code, etc), and the current session is not running under SSH.

        It also tests whether stdout is a tty and tries to detect the number of
        colours supported by the terminal, and sets the TERM_NCLRS variable.
        """

        docsh -TD
        return
    }

    # If TERM_PROGRAM is already set, leave it alone
    # - macOS sets TERM_PROGRAM=Apple_Terminal
    # - also don't try this if we're in an SSH session
    if [[ -z ${TERM_PROGRAM-}  && -z ${SSH_CLIENT-} ]]
    then
        ### Try to detect known terminal emulators

        # Get the name of the shell's parent process
        # - use read to strip leading whitespace
        local pcmd ppid
        read -r ppid <<< $( command ps -o 'ppid=' -p $$ )
        pcmd=$( command ps -o 'command=' -ww -p "$ppid" )

        if  [[ $pcmd == *'bin/vshd '*
            && ${BROWSER-} == /usr/bin/garcon-url-handler ]]
        then
            # In ChromeOS Container, likely running CrOS Terminal
            # - also [[ -r /dev/.cros_milestone ]]
            # - also [[ -r /opt/google/cros-containers/etc/lsb-release ]]
            export TERM_PROGRAM=ChromeOS_Terminal
        fi
    fi

    # Test whether stdout is a terminal, then determine the number of colours it can display.
    # - see `man terminfo` for a list of terminal capabilities that may be queried by tput.
    # - macOS Terminal.app and ChromeOS Terminal both return 256.
    if [[ -t 1 ]]
    then
        declare -gi TERM_NCLRS
        TERM_NCLRS=$( command tput colors || echo 2 )
    fi

    # However, terminals such as ChromeOS Terminal actually support 16M colours, even though
    # they only advertise 256. To account for this, we can set COLORTERM (see
    # https://jdebp.uk/Softwares/nosh/guide/TerminalCapabilities.html).
    # NB, Apple's Terminal.app only supports 8-bit color (256 colors).
    if [[ ${TERM_PROGRAM-} == @(ChromeOS_Terminal|vscode) ]]
    then
        export COLORTERM=truecolor
    fi
}
