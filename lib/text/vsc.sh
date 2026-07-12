# Launch VS-Code editor

vscr() {
    # alias to open in a re-used window
    vsc -r "$@"
}

vscn() {
    # alias to open in a new window
    vsc -n "$@"
}

# the function _vscl_aliases below reads the config file to link commonly used
# projects with aliases:
# - bread
# - food
# completions for the project aliases are set up in the _vsc.bash file:

: """Launch Commonly-Used VS-Code Projects Using Aliases

    Usage: vscode-wrapper [--proj=word] [vs-code arguments ...]

    All arguments other than --proj=word are passed to the code command. Refer to
    the docs of that command using 'code --help'.

    Associations between alias names and directories may be defined in a config
    file at '~/.config/vsc-launcher/aliases'. The alias definitions follow a simple
    'name = path' syntax, with one definition per line. The names may include alpha-
    numeric characters, periods, and dashes. Paths that start with '~/' will be
    expanded using the HOME variable, but no other expansions will be performed.

    Examples

      # open the 'bread' project directory in a new window
      vscode-launcher -n --proj=bread
"""

vsc() {

	[[ $# -eq 0  || $1 == @(-h|--help) ]] &&
    	{ docsh -TD; return; }

    # import project aliases, if present
    local -A projs=()
    _vscl_aliases projs \
        || return

    # projs["bread"]="$HOME/Documents/Food and Diet/Bread"
    # projs["food"]="$HOME/Documents/Food and Diet"

    # vs-code command path
    local vsc_cmd
    vsc_cmd=$( builtin type -P code ) \
        || return 9

    # check for --proj arguments
    local a i=1 j k
    for a in "$@"
    do
        if [[ $a == --proj=* ]]
        then
            # make a valid vs-code command line using the project path
            a=${a#'--proj='}
            [[ -v "projs[$a]" ]] \
                || { err_msg 3 "project not found: '$a'"; return; }

            j=$((i-1))
            k=$((i+1))
            set -- "${@:1:j}" "${@:k}" "${projs[$a]}"
        fi
        (( ++i ))
    done

    "$vsc_cmd" "$@"
}

_vscl_aliases() {

    : """Read vsc-launcher alias definition file,
        then add aliases to projs array
    """

    [[ $# -eq 1 ]] \
        || return 20

    # nameref to projs
    local -n p_arr=$1
    shift

    # read aliases
    local alias_fn=${XDG_CONFIG_HOME:-"$HOME/.config"}/vsc-launcher/aliases

    if [[ -s $alias_fn  && -r $alias_fn ]]
    then
        local ln alines a d

        mapfile -t alines < "$alias_fn"

        for ln in "${alines[@]}"
        do
            # match name and path using regex
            # - this would work too: a=${ln%% = *}; d=${ln#* = }
            [[ $ln =~ ^[[:space:]]*([^[:space:]]+)[[:space:]]+=[[:space:]]+(.*)$ ]]
            a=${BASH_REMATCH[1]}
            d=${BASH_REMATCH[2]}

            [[ -n $a  && -n $d ]] \
                || { err_msg 5 "unable to parse alias: '$ln'"; return; }

            [[ $d == \~/* ]] \
                && d=$HOME/${d#'~/'}

            # add alias to projs array
            # shellcheck disable=SC2004
            p_arr[$a]=$d \
                || return
        done
    fi
}
