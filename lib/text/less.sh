# less pager

# Wrap text before input to less
# fmt -w $(tput cols) | less
# or
# fold -sw80 longlines.txt | less
# - attempted to do limited line length, but it looked bad...


if [[ -n $( command -v lesspipe ) ]]
then
    lessz() {

        # less handling of compressed files, e.g. gz and tar files, transparently
        # - i think this script sometimes causes problems, and it's not well documented,
        #   but it's handy when it works.
        # - this is specifically the Debian lesspipe version, but there are others.

        LESSOPEN="| $( command -v lesspipe ) %s"   \
        LESSCLOSE="$( command -v lesspipe ) %s %s" \
        less "$@"
    }
fi

if [[ -n $( command -v highlight ) ]]
then

    less-hl() (

        # View source code in less with syntax highlighting
        #
        # Usage
        #
        # less-hl [opts] <file>
        #
        # -s <style> : set style (see note below)
        # -O <fmt>   : ansi, truecolor, or xterm256
        #
        # - last arg is filename ('-' may work for stdin)
        # - other args are options for less (use -- first)
        #
        # Notes
        #
        # - To show config dirs and styles (themes), use:
        #       highlight --list-scripts=themes
        # - Recommended:
        #   + github with truecolor (light BG)
        #   + bright with xterm256 (light BG)
        # - When using ansi output format, there is only 1 (hard-coded)
        #   colour theme.

        [[ $# -eq 0 || $1 == @(-h|--help) ]] \
            && { docsh -TD; return; }

        # parse args
        local hl_style hl_outfmt
        local OPT OPTARG OPTIND=1

        while getopts "s:O:" OPT
        do
            case $OPT in
              (s) hl_style=$OPTARG ;;
              (O) hl_outfmt=$OPTARG ;;
            esac
        done
        shift $((OPTIND - 1))

        # get filename and options from command line
        local fn less_opts hl_opts

        fn=${@:(-1):1}

        less_opts=( "${@:1:$#-1}" )
        less_opts+=( -R )

        hl_opts=()

        # TODO:
        # - try styles with dark BG

        # syntax from glob
        if [[ $fn == *.md.txt ]]
        then
            hl_opts+=( "--syntax=markdown" )
        fi

        # output format
        hl_opts+=( -O "${hl_outfmt:-xterm256}" )

        # style
        if array_match hl_opts xterm256
        then
            hl_opts+=( -s "${hl_style:-bright}" )

        elif array_match hl_opts truecolor
        then
            hl_opts+=( -s "${hl_style:-github}" )
        fi

        (
            set -x
            less "${less_opts[@]}" < <(highlight "${hl_opts[@]}" "$fn")
        )
    )
fi
