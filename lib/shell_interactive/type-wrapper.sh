type-wrapper() {

    # Wrap the type builtin and add -F
    #
    # Usage: type-wrapper [args for \`type\`] <command-name> ...
    #
    # This function wraps the type command, and adds the -F option to suppress
    # printing function definitions in the same way as 'declare -F'. Otherwise,
    # all arguments are passed to type.
    #
    # E.g. 'type-wrapper -aF ...' runs \`type -a\` on all arguments, which indicates
    # all the ways that each command would be interpreted (e.g. executable, shell
    # function, builtin, etc.). However, the output of type is passed through a
    # \`sed\` filter that suppresses the printing of any function definitions.

    [[ $# == 0  || $1 == @(-h|--help) ]] \
        && { docsh -TD; return; }

    # option parsing for -F
    # - the type Bash builtin takes only option flags and names
    local i a filt
    local args=( . "$@" )
    unset 'args[0]'

    for (( i=1; i<=$#; i++ ))
    do
        a=${args[i]}

        [[ $a == '--'  || $a != -?* ]] &&
            break

        if [[ $a == *F* ]]
        then
            # -F option used
            filt='
                / is a function$/ {
                    p
                    # start "loop": terminates on closing brace
                    : fn
                        # use N because n would print
                        N
                        # strip previous line from pattern
                        s/^.*\n//
                        # if line is just a closing brace, filter is finished
                        /^}$/ d
                        # otherwise, loop to check the next line
                        b fn
            }'

            if [[ $a == -F ]]
            then
                unset 'args[i]'
            else
                a=${a//F/}
                args[i]=$a
            fi
        fi
    done

    if [[ -n ${filt-} ]]
    then
        builtin type "${args[@]}" \
            | sed "$filt"
    else
        builtin type "${args[@]}"
    fi
}
