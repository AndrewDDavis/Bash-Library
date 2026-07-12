# deps
import_func array_strrepl str_to_words \
    || return

: """Expand an alias to a command line, using recursion if necessary

    Usage: alias-resolve [options] <name> [array-name]

    This function checks whether 'name' is defined as an alias in the current
    environment. The result is written to 'array-name' if supplied, or to an array
    called CMD_ALIAS.

    If no alias was found, the resulting array will contain only 1 element, the
    command itself. Otherwise, the array will contain the command alias split into
    words, including any arguments and variable definitions from the alias. If the
    alias initially resolves to another alias, the procedure repeats recursively
    until the resulting command is not an alias.

    This function facilitates the use of command aliases in shell functions. In the
    Bash shell, aliases may be expanded in functions if they were defined when the
    function definition was read, and either the shell was interactive or the
    'expand_aliases' option was set. In a typical setup where the function
    definitions are read during the shell initialization process, the aliases will
    not be expanded.

    Care is needed to handle aliases that include variable assignments before the
    command, e.g. alias ls='LC_COLLATE=en_CA.utf8 ls --color=auto'. After such a
    command is captured in an array variable, the shell would normally fail to run
    it, since it would try to interpret the variable assignment as a command. In
    such cases, alias-resolve adds 'env' to the start of the command array so the
    command will run as expected, unless the -e option is used.

    Options

      -e
      : Prevent adding 'env' as the first array element, even if the array would
        otherwise start with a variable assignment.

      -p
      : Print the resulting expansion to STDOUT after resolving the alias.

    Examples

      alias-resolve ll ls_cmd
      # ls_cmd may be: ( LC_COLLATE=C.utf8 ls --color=auto -lh )
"""

alias-resolve() {

    # defaults and options
    local _env=1 _pr

    local flag OPTARG OPTIND=1
    while getopts ':ehp' flag
    do
        case $flag in
            ( e ) _env=0 ;;
            ( h ) docsh -TD; return ;;
            ( p ) _pr=1 ;;
            ( \? ) err_msg 2 "unknown option: '-$OPTARG'"; return ;;
            ( : )  err_msg 2 "missing argument for -$OPTARG"; return ;;
        esac
    done
    shift $(( OPTIND-1 ))

    # positional args
    # - name is the command to resolve
    # - al_words is the nameref to the array of alias words
    local name=${1:?"name required"}
    shift

    if (( $# > 0 ))
    then
        local -n al_words=$1
        shift
    else
        local -n al_words=CMD_ALIAS
    fi

    (( $# == 0 )) \
        || { err_msg 5 "too many arguments: '$*'"; return; }

    # return false for no current alias definition
    builtin alias "$name" &>/dev/null \
        || return 1

    # Recursively resolve the alias, up to 100 iterations
    local cmd=$name
    al_words=( "$cmd" )
    local i=0 new_words=() new_cmd

    while builtin alias "$cmd" &>/dev/null
    do
        # fetch defined alias and split into words, respecting quoting
        str_to_words -q new_words "${BASH_ALIASES[$cmd]}"

        # replace cmd in the al_words array with its alias words
        # - e.g. ll -> ls -l
        array_strrepl al_words "$cmd" "${new_words[@]}"

        # identify the new command word, after any env var assignments
        new_cmd=$( array_match -p new_words '^[^=]+$' )

        # detect recursive alias
        [[ $new_cmd == "$cmd" ]] &&
            break

        cmd=$new_cmd

        # limit runaway loop
        (( ++i ))
        (( i > 99 )) && {
            err_msg 99 "too many iterations"
            return
        }
    done

    if (( _env )) && [[ ${al_words[0]} == *=* ]]
    then
        # add env cmd
        al_words=( env "${al_words[@]}" )
    fi

    if [[ -v _pr ]]
    then
        printf '%s:  %s\n' "$name" "${al_words[*]}"
    fi
}
