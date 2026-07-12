# deps
import_func alias-resolve array_strrepl \
    || return

# Search readline or stty keybindings
#
# Usage
#
#   bind-grep [-s] [grep-options] [pattern]
#   bind-grep -k <string>
#
# This function gathers a list of readline keybindings for functions, macros, and
# shell commands, then runs a 'grep' command to filter the list. The list is
# prefiltered to improve readability and remove the numerous 'self-insert' lines.
# Unless using '-k', all command-line arguments are passed to 'grep'. The default
# grep options are '-E' and '-i', to match using ERE patterns in a case-
# insensitive manner. If no pattern is supplied, all entries are matched.
#
# Options
#
#   -s
#   : Print or match against the filtered output of 'stty -a' to show the
#     terminal's keybindings rather than Readline's.
#
#   -k
#   : Print the bindings to the supplied string. The string is often a single
#     character (e.g. 'n'), but may be a sequence (e.g. '^[[5~' for PgUp).
#
#     If the string contains '^[', which represents the escape character, it is
#     removed. This allows matching to a sanitized string produced from bind's
#     output.
#
#     When using '-k', matching is performed by 'awk', in the same way that
#     'grep -iE' would. Unmatched opening brackets and parentheses ('[', '('),
#     which would cause an error, are automatically escaped by bind-grep. Other
#     regex meta-chars ('\', '^', '$', '.', '|', '*', '+', '?') should be escaped
#     with '\' to be matched literally.
#
#     Most characters, including all letters and digits, are regular expressions
#     that match themselves. To match literal meta-characters such as '.', '*',
#     '(', '[', '|', '{', '^', and '$', they should be quoted by preceding with a
#     backslash or enclosing in square brackets, e.g. '\*' or '[.]'. This includes
#     the backslash character itself, which is also double printed in bind's
#     double-quoted output; thus, to search for bindings on '\', you would use
#     -k '\\\\' or -k '[\][\]'.
#
# Other common queries that can be accomplished using bind:
#
#   - To filter a list of the **readline function-names** without showing their bindings,
#     you can use 'bind -l | grep ...'.
#
#   - To filter a list of **readline variables** and print their state, you can use
#     'bind -v | grep...'.
#
#   - To query which keys invoke a function, you can use 'bind -q <name>'. The return
#     status also indicates whether the function is bound to any keys.
#
# Examples
#
#   # print bindings that have to do with history or completion
#   bind-grep 'hist|comp'
#
#   # print bindings on 'n'
#   bind-grep -k n
#   # '\\en', '\\e\\C-n', '\\C-x\\C-n', etc.
#
#   # print bindinds to '{'
#   bind-grep -k '\{'
#
#   # print all defined terminal bindings
#   bind-grep -s -v undef

bind-grep() {

    [[ $# -eq 0  ||  $1 == -h ]] &&
        { docsh -TD; return; }


    # grep command and default args
    local grep_pth grep_cmd=()

    grep_pth=$( builtin type -P grep ) \
        || return 9

    # - use the calling shell's alias for grep, if any (e.g. 'grep --color=auto')
    alias-resolve grep grep_cmd \
        || grep_cmd=( grep )

    # - avoids replacing /path/to/grep with /path/to/path/to/grep
    array_strrepl grep_cmd grep "$grep_pth"

    grep_cmd+=( -Ei )


    # defaults and opt-parsing
    local _k _s _filt n

    local flag OPTARG OPTIND=1
    while getopts ':k:s' flag
    do
        case $flag in
            ( k )
                # filter:
                # - escape unmatched brackets and parentheses
                # - remove escape sequence ('^['), e.g. in '^[[5~' for PgUp
                _filt='
                    s/\^\[//g
                    s/(^|[^\])(\[[^]]*|\([^)]*)$/\1\\\2/
                '

                _k=$( command sed -E "$_filt" <<< "$OPTARG" )
            ;;
            ( s )
                _s=1
            ;;
            ( \? )
                # preserve arguments for grep
                (( OPTIND-- ))
                break
            ;;
            ( : )
                err_msg 3 "missing argument for '-$OPTARG'"
                return
            ;;
        esac
    done

    # preserve '--'
    n=$(( OPTIND-1 ))
    [[ $n -gt 0  && ${!n} == '--' ]] &&
        (( n-- ))

    shift $n


    # all other args are for grep
    # - by default, match all
    (( $# > 0 )) ||
        set -- '^'

    grep_cmd+=( "$@" )


    # gather the binding definitions to match
    local binddefs_str

    if [[ -v _s ]]
    then
        # use the bindings output of stty
        binddefs_str=$(
            set -o pipefail
            command stty -a \
                | command sed 's/;[[:blank:]]*/\n/g' \
                | command grep ' = ' \
                | command grep -Ev '^(line|min|time)'
        ) || return

    else
        # gather the binding definitions for functions, macros, and shell commands
        # - trailing newlines are stripped away by $(...)

        binddefs_str=$( builtin bind -p )$'\n'
        binddefs_str+=$( builtin bind -s )$'\n'
        binddefs_str+=$( builtin bind -X )$'\n'


        # format the binding definitions
        _filt='
            # remove empty lines and self-insert lines
            /^$/ { next; }
            /: self-insert$/ { next; }

            # improve formatting of (not bound) lines
            /^# .*\(not bound\)$/ {
                sub(/ \(not bound\)$/, "")
                sub(/^#/, "# (none):")
                next
            }

            # align function names
            { printf "%-10s : %s\n", $1, $2; }
        '

        # awk's -F sets field-separator
        binddefs_str=$( command awk -F ': ' "$_filt" - <<< "$binddefs_str" )
    fi


    if [[ -z ${_k-} ]]
    then
        # match against the whole line: keys, functions, macros, and shell commands
        "${grep_cmd[@]}" <<< "$binddefs_str"

    else
        # with -k, only match against bindings

        # awk beats sed for this appliction:
        #
        # - you can store the original line as a variable, and still match against
        #   the scrubbed key-string; or use a function, etc. Then you don't have to
        #   bother with line numbers and arrays, etc., as you would with sed.
        #
        # - also you can pass the _k variable into the program using -v, and keep the
        #   program in single-quotes, which simplifies escaping some chars.

        _filt='
            # ignore (not bound) lines
            /^# / { next; }

            _match_scrubbed( $0, k ) { print; }

            function _match_scrubbed( s, c ) {

                # strip quotes, meta keys, and everything after colon
                gsub(/(^"|"[[:blank:]]+: .+$|\\C-|\\e)/, "", s)

                # match, case-insensitive, ERE
                return ( tolower(s) ~ tolower(c) ? 1 : 0 )
            }
        '

        command awk -v "k=${_k}" "$_filt" <<< "$binddefs_str"
    fi
}
