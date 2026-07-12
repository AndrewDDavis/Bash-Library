# TODO:
# - also highlight the pattern match in the usual way for grep
# - print history lines like history does, with the line no. and date;
#   the history file contains lines for the date, and you can roughly
#   filter them with:
#   grep -v '^#[0-9]' .bash_extended_history | wc -l

# deps
import_func array_from_glob \
    || return

hist-grep() {

    : """Search the shell history file(s) for occurrences of a pattern

        Usage: hist-grep [grep-args] <pattern>

        Pattern matching is performed by \`grep -E\`, and the glob for history files
        is \`~/.bash*history\`.
    """

    [[ $# -eq 0  || $1 == @(-h|--help) ]] &&
        { docsh -TD; return; }

    local grep_cmd sed_cmd rxc

    grep_cmd=( "$( builtin type -P grep )" -E ) \
        || return 6

    sed_cmd=( "$( builtin type -P sed )" -E ) \
        || return 7

    # all arguments passed to grep
    grep_cmd+=( "$@" )
    shift $#

    # regex to match commands
    rxc='((sudo|export|local|declare|typeset)[ ]+(-[^ ]+[ ]+)?)?[^ =]+=?'

    # history files to search
    local hfn_glob hfns=()

    hfn_glob="$HOME/.bash*history"
    array_from_glob hfns "$hfn_glob"
    # hfns=( $hfn_glob )

    [[ -v hfns[*] ]] ||
        { err_msg 9 "no history files matched glob: '$hfn_glob'"; return; }

    # search each file
    local fn grep_out sfilt

    for fn in "${hfns[@]}"
    do
        # search, then filter output
        if grep_out=$( "${grep_cmd[@]}" "$fn" )
        then
            # report history filename (underlined)
            printf '\n%s:\n\n' "${_cul-}${fn/#"$HOME"/\~}${_cru-}"

            # sed filter
            sfilt="
                # remove file name
                s|^${fn}:||

                # remove hist-grep commands?
                /^hist-grep.*/ d

                # commands get bold styling
                s/^($rxc)/${_cbo-}\1${_crb-}/

                # also bold commands following | or ;
                s/ (\||;) ($rxc)/ \1 ${_cbo-}\2${_crb-}/g
            "

            printf '%s\n\n' "$grep_out" \
                | "${sed_cmd[@]}" "$sfilt"
        fi
    done
}
