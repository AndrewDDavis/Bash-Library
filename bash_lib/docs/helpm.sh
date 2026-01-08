# Use help bash-completion for helpm
# - NB complete -p help -> complete -F _comp_cmd_help help
#complete $(complete -p help | sed 's/^complete //; s/help$/helpm/')

# TODO:
# - completion
# - scriptify?

: """Display help pages for shell builtins, functions, or scripts

    Usage

        helpm <command>

    If the command is a shell builtin or keyword, the help page is viewed using
    the 'less' command or the value of \$PAGER. The 'help -m' command is used to
    format the text similar to a man page, with some additional styling added by
    helpm.

    If the command is a function or script, 'docsh' is called to gather and view
    the documentation.
"""

helpm() {

    [[ $# -eq 0 || $1 == @(-h|--help) ]] &&
        { docsh -TD; return; }

    [[ $# -gt 1 ]] &&
        { err_msg 2 "too many args: '$*'"; return; }

    local cmd
    cmd=$1
    shift


    # check command type
    # `alias', `keyword', `function', `builtin', `file' or `'
    local types _a _b _f _k _p
    types=$( builtin type -at "$cmd" )

    [[ $types == *alias* ]] && _a=1
    [[ $types == *builtin* ]] && _b=1
    [[ $types == *function* ]] && _f=1
    [[ $types == *keyword* ]] && _k=1
    [[ $types == *file* ]] && _p=1

    [[ -v _a ]] \
        && err_msg w "'$cmd' refers to an alias"

    if [[ ( -v _b || -v _k || -v _p )  &&  -v _f ]]
    then
        err_msg w "'$cmd' refers to both a function and a command"

    elif [[ ! ( -v _b || -v _f || -v _k || -v _p ) ]]
    then
        err_msg 2 "no matches for command: '$cmd'"
        return
    fi


    # show help
    if [[ -v _f ]]
    then
        # function
        docsh -TDf "$cmd"
    fi

    if [[ -v _p ]]
    then
        # command, possibly a script
        if [[ $( command file -L "$( builtin type -P "$cmd" )" ) == *text* ]]
        then
            docsh -TDp "$cmd"
        else
            err_msg w "'$cmd' refers to a file, but it does not appear to be a script"
        fi
    fi

    if [[ -v _b || -v _k ]]
    then
        # builtin or keyword
        local help_txt filt
        help_txt=$( builtin help -m "$cmd" )

        # use sed to make the headings bold, like a man page
        # - for more, see the csi_strvars function:
        #   [[ -z ${_cbo-} ]] && csi_strvars -pd
        # - not using _cbo, as it includes the prompt-specific \[...\]
        local _bld _rsb _rst
        _bld=$'\e[1m'
        _rsb=$'\e[22m'
        _rst=$'\e[0m'

        filt="s/^([[:upper:] ]+)\$/${_bld}\1${_rsb}/"

        help_txt=$( command sed -E "$filt" <<< "$help_txt" )

        # NB, default user options for less will be respected, since they're in the
        # exported variable 'LESS', rather than an alias.
        # - -R ensures that the text style characters will be respected.
        command less -R <<< "$help_txt"
    fi
}
