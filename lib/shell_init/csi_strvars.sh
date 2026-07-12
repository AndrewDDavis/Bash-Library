csi_strvars() {

    [[ ${1-} == @(-h|--help) ]] && {

        : """Define variables to apply styles and colours to terminal text.

        Usage

          csi_strvars [options]

        This function defines styling string variables that begin with '_c', e.g.
        \`_cbo\` for bold text, and \`_crs\` to reset all styling back to default.

        By default, this function defines the variables without evaluating the ANSI
        escape codes and control sequences. Thus, they are suitable for printing (e.g.
        \`printf '%s' ...\` will contain backslash escapes) or evaluating (e.g. in a
        prompt, or with \`printf %b ...\`). However, in my .bashrc, I run
        \`csi_strvars -pd\`, to allow the strings to be used in prompts and in shell
        functions.

        Options

          -p
          : Output in prompt-friendly format (surrounds non-printing characters with
            \`\\[...\\]\` to avoid problems with Bash history).

          -d
          : Output in dynamic format (control sequences are evaluated, rather than
            using backslash escapes). This is useful e.g. for functions called in PS1.

        In practice, to prevent re-running this function unnecessarily, a previous run
        may be detected using a test like the following:

          [[ -n \${_cbo-} ]] ||
              csi_strvars

        To import the function itself it is recommended to use the import_func
        function, or a test like \`[[ \$( type -t csi_strvars ) == function ]]\`.

        Running this function also defines the \`_csi_str\` function, which may be used
        to define custom string variables that are wrapped in control sequences:

          _csi_str [-p] [-d] <varname> <code>

        where \`code\` is an ANSI code, such as '0' for reset or '1' for bold, and
        \`varname\` is the variable that will be set.

        Notes

        - For a good overview of ANSI escape codes, see notes, or:
          https://www.baeldung.com/linux/formatting-text-in-terminals

        - For a view of the 256-colour palette, see:
          https://askubuntu.com/a/821163/52041

        - The codes are written literally here, with delimiting '\[' and '\]' for prompts,
          rather than using \`\$'...'\` or the '@P' operator. Strings defined this way are
          reliably interpreted by the shell at each prompt when they are used in PS1,
          although I have found the dynamic versions work just fine in PS1 as well.

        - Consider also using tput, rather than hard-coded ANSI sequences:
            + \`setaf\` & \`setab\` to set ANSI fg and bg
            + see setaf in \`man terminfo\` for colour numbers -> names
            + \`blue=\$( tput setaf 4 )\`
            + \`reset=\$( tput sgr0 )\`
            + \`dim=\$( tput dim )\`
        """
        docsh -TD
        return
    }

    # Text style sequences
    _csi_str "$@" _cbl '5'     # blink
    _csi_str "$@" _cbo '1'     # bold
    _csi_str "$@" _cdm '2'     # dim (mutually exclusive with bold)
    _csi_str "$@" _chd '8'     # hidden
    _csi_str "$@" _cit '3'     # italic
    _csi_str "$@" _civ '7'     # inverse video (reverse fg & bg)
    _csi_str "$@" _col '53'    # overline
    _csi_str "$@" _cst '9'     # strikethrough
    _csi_str "$@" _cuc '4:3'   # curly underline (not in Konsole)
    _csi_str "$@" _cul '4'     # underline
    _csi_str "$@" _cuu '21'    # double underline (not in Konsole)

    _csi_str "$@" _crs '0'     # reset all
    _csi_str "$@" _crb '22'    # reset bold or dim
    _csi_str "$@" _crd '22'    # reset bold or dim
    _csi_str "$@" _crh '28'    # reset hidden
    _csi_str "$@" _cri '23'    # reset italic
    _csi_str "$@" _crk '25'    # reset blink
    _csi_str "$@" _cro '55'    # reset overline
    _csi_str "$@" _crt '29'    # reset strikethrough
    _csi_str "$@" _cru '24'    # reset underline or double underline
    _csi_str "$@" _crw '4:0'   # reset curly underline
    _csi_str "$@" _crv '27'    # reset inverse


    # Get terminal colour capability, unless defined in enclosing shell
    [[ -v TERM_NCLRS ]] || {

        # use tput or safe-ish default
        declare -i TERM_NCLRS
        TERM_NCLRS=$( command tput colors ) \
            || TERM_NCLRS=8
    }


    # Define standard FG + BG colours from the 8-colour palette (+ default)
    if (( TERM_NCLRS >= 8 ))
    then
        _csi_str "$@" _cfg_r '31'  # red FG
        _csi_str "$@" _cfg_g '32'  # green FG
        _csi_str "$@" _cfg_b '34'  # blue FG

        _csi_str "$@" _cfg_c '36'  # cyan FG
        _csi_str "$@" _cfg_m '35'  # magenta FG
        _csi_str "$@" _cfg_y '33'  # yellow FG

        _csi_str "$@" _cfg_k '30'  # black FG
        _csi_str "$@" _cfg_w '37'  # white FG
        _csi_str "$@" _cfg_d '39'  # default FG


        _csi_str "$@" _cbg_r '41'  # red BG
        _csi_str "$@" _cbg_g '42'  # green BG
        _csi_str "$@" _cbg_b '44'  # blue BG

        _csi_str "$@" _cbg_k '40'  # black BG
        _csi_str "$@" _cbg_w '47'  # white BG
        _csi_str "$@" _cbg_d '49'  # default BG
    fi

    # If supported, define colours using the 256-colour palette instead
    # - would like to use '38:5:x' instead, but not supported in ChromeOS terminal
    if (( TERM_NCLRS >= 256 ))
    then
        _csi_str "$@" _cfg_r '38;5;124'
        _csi_str "$@" _cfg_g '38;5;28'
        _csi_str "$@" _cfg_b '38;5;25'
    fi
}


_csi_str() {

    [[ $# -eq 0  || $# -lt 2  || $1 == -h ]] &&
        { csi_strvars -h; return; }

    # opts and args
    local _p _d flag OPTIND=1

    while getopts 'pd' flag
    do
        case $flag in
            ( p ) _p=1 ;;
            ( d ) _d=1 ;;
            ( * ) return 2 ;;
        esac
    done
    shift $(( OPTIND-1 ))

    # nameref var
    local -n _s=$1  || return
    local _c=$2     || return
    shift 2

    # define ctrl seq and prompt introducers and terminators
    local CSI='\e['
    local CST='m'
    local prNPI='\['
    local prNPT='\]'

    # wrap code with CSI and CST
    _s="${CSI}${_c}${CST}"

    # for prompt string (-p), enclose in '\[...\]'
    [[ -n ${_p-} ]] &&
        _s="${prNPI}${_s}${prNPT}"

    # for evaluated string (-d), evaluate the escapes
    [[ -n ${_d-} ]] &&
        _s="${_s@P}"
}
