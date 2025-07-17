# dependencies
import_func csi_strvars \
    || return

# docsh docs
: """Apply terminal control sequences to format text, especially the prompt.

    Usage: prompt_colourize [options] s1 s2 s3

    The arguments s1, s2, s3 are required, and represent the strings that will form
    the prompt. Empty string(s) may be passed to effectively omit them.

    Options

      -n <#> : Number of colours supported by terminal (default 8). This value should
              typically be available by running \`tput colors\` in a terminal, though
              this may underestimate the true value (e.g. for ChromeOS Terminal).
      -u     : Colouring intended for a user account (default)
      -0     : Colouring intended for root account

    Example

      PS1=\$( prompt_colourize '\u@\h' '\W' '\$' )

    Background

    See the \"Terminal Control Sequences\" section of my Shell and Terminal Emulators
    notes file, and the \"Prompt\" section for the particulars of prompt strings.
"""

prompt_colourize() {

    [[ $# -lt 3  || $1 == @(-h|--help) ]] \
        && { docsh -TD; return; }

    # Args and defaults
    local -i nclrs=8
    local c_style=user

    [[ -v TERM_NCLRS ]] &&
        nclrs=$TERM_NCLRS

    local flag OPTARG OPTIND=1
    while getopts ":u0n:" flag
    do
        case $flag in
            ( n ) nclrs=$OPTARG ;;
            ( u ) c_style=user ;;
            ( 0 ) c_style=root ;;
            ( \? | : ) err_msg 2 "getopts: $flag on '-$OPTARG'"; return ;;
        esac
    done
    shift $(( OPTIND-1 ))

    (( nclrs >= 8 )) ||
        { err_msg 4 "nclrs = $nclrs"; return; }


    # Define variables for control sequence codes
    # - options cause prompt escapes to be added, and escapes to be evaluated
    [[ -n ${_cbo-} ]] ||
        csi_strvars -pd


    # Augment strings passed in command call
    # - NB expansion of ${s1:+...} expands to ... if s1 is not null
    # - typically, we want a space after each part, if it is not empty, so each
    #   expansion ends in a space
    # - also reset the formatting, to prevent underlining the space
    local s1 s2 s3

    if [[ $c_style == user ]]
    then
        # User style sequence:
        # - green (user), blue (pwd), bold blue (prompt)
        # - expansion of ${param-word} subs word if param is unset
        s1=${1:+"${_cfg_g}${1}${_crs} "}
        s2=${2:+"${_cfg_b}${2}${_crs} "}
        s3=${3:+"${_cbo}${_cfg_b}${3}${_crs} "}

    elif [[ $c_style == root ]]
    then
        # Root style sequence:
        # - maroon (pwd), underlined (user), normal (prompt)
        s1=${1:+"${_cfg_m}${1}${_crs} "}
        s2=${2:+"${_cul}${2}${_crs} "}
        s3=${3-}" "
    fi

    # prepend a reset code and print prompt string
    printf '\001\e[0m\002%s%s%s\n' "$s1" "$s2" "$s3"
}
