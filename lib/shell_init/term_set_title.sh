term_set_title() {

    [[ $# == 0 || $1 == @(-h|--help) ]] && {

        : """Change the terminal emulator's window and tab titles.

        Usage: term_set_title [opts] [code] <string>

        The window and/or tab titles of the present terminal instance are set with escape
        sequences similar to those described for the PS1 variable of the prompt. In fact,
        the escape sequence may be embedded into PS1 between \[ and \].

        The format is: \e]X;<the window title>BEL, where X is a code to specify what to
        set:
        - 1 = tab title
        - 2 = window title
        - 0 = both

        This function accepts the codes as either words or numerical values. The default
        is to set the tab title (code 1).

        Options

          -p
          : wrap the output in \\[...\\] so it can be safely incorporated into a prompt

        Notes

        - My .bash_logout file sets a null title for the window and tab, using
          printf '\e]0;\a'.

        - In Terminal.app prefs on macOS, I also have the following settings:
            + Tab title set to \"working directory ...\" (without path)
            + Selected \"show other items...\" and \"show activity indicator\"
            + Window title set to working directory with path, and TTY name

        - On ChromeOS, the Terminal does not have its own settings for the tab and
          window titles, and gives each tab the simple title 'Terminal'. It requires
          code 2 to change the tab title.
        """
        docsh -TD
        return
    }

    # prompt opt
    local _p
    [[ $1 == -p ]] &&
        { _p=1; shift; }

    # setting code: 'window', 'tab' (default), or 'both'
    local tcode=1

    case $1 in
        ( tab | 1 )
            tcode=1
            shift
        ;;
        ( window | 2 )
            tcode=2
            shift
        ;;
        ( both | 0 )
            tcode=0
            shift
        ;;
    esac

    # on CromeOS, use window code to set tab titles
    if [[ -r /dev/.cros_milestone || ${TERM_PROGRAM-} == ChromeOS_Terminal ]]
    then
        (( tcode == 1 )) && tcode=2
    fi

    # printf format string (printf will expand these escape sequences)
    local p_fmt='\e]%s;%s\a'

    # prompt wrapping: use octal 001 and 002 for \[ and \]
    [[ -z ${_p-} ]] ||
        p_fmt='\001'${p_fmt}'\002'

    printf "$p_fmt" $tcode "$@"
}
