# import dependencies
import_func str_to_words array_match array_irepl array_reindex \
    || return

realias() {

    [[ $# -eq 0  || $1 == @(-h|--help) ]] && {

        : """Define a command alias, retaining any previous definitions

        Usage: realias <command> <alias-string>

        Aliases commonly change or augment the usual effect of a command by adding
        variable assignments before the command, and option arguments after it. This
        function allows the definition of a command alias that retains any previous
        changes to the command. It first checks whether an alias is defined for
        'command' in the current shell, then:

          - If no alias is defined, a new one is created using the alias-string. In
            this case, the effect of running 'realias cmd \"cmd -a\"' is the same
            as using 'alias cmd=\"cmd -a\"'.

          - If an alias exists, it is augmented with the new variable assignments and
            arguments. The new arguments are added at the end of the alias, where they
            usually take precedence over any previous conflicting ones. Any arguments
            in the new alias string that were already part of the existing alias are
            removed and re-added, for the same reason.

        This function may be used in an interactive shell, or in shell init files like
        ~/.bashrc and files sourced from it. However, it cannot be used effectively
        within a shell function, since alias definitions in the body of a function do
        not take effect until after the function is executed (refer to the Bash manual
        for details). To use an alias defined in the environment within a function,
        refer to the 'alias-resolve' function.

        Options

          -f : skip the check for equivalent old and new commands in the alias strings,
               just augment the original command with the new arguments.

        Examples

          realias ls 'ls --color'

          # - with no previous alias, the new alias is:
          #   ls='ls --color'
          #
          # - if the previous alias was 'ls -h', the new alias is:
          #   ls='ls -h --color'

          realias ls 'ls -h'

          # - now, the -h flag is moved to the end, so the alias becomes:
          #   ls='ls --color -h'

          # Note that realias will report an error if the new alias would change the
          # command name, e.g.:

          alias fgrep='grep -F'
          realias fgrep 'fgrep --color=auto'
          # realias reports an error

          # To avoid this, you could check for an fgrep command or alias first, e.g.
          # using the command or alias builtins. Otherwise, you can use the '-f'
          # option to skip the check and retain the old command.
          realias -f fgrep 'fgrep --color=auto'
          # now fgrep='grep -F --color=auto'
        """
        docsh -TD
        return
    }

    # -f opt
    local _f
    [[ $1 == '-f' ]] &&
        { _f=1; shift; }

    # arg sanity
    [[ $# -eq 2 ]] ||
        return 2

    local alname=$1
    local newal_str=$2
    shift 2


    if ! builtin alias "$alname" &>/dev/null
    then
        # no current alias definition

        # shellcheck disable=SC2139
        builtin alias "$alname"="$newal_str"

    else
        # alias defined, modify it with the words of the new string:
        # - do word splitting and quote removal on the old and new alias strings, while
        #   respecting quotes and escapes.
        # - NB, not recursively resolving the alias for alname, only redifining the alias;
        #   the alias-resolve function can resolve recursively.

        local -a al_words new_words

        str_to_words al_words "${BASH_ALIASES[$alname]}"
        str_to_words new_words "$newal_str"

        # identify the command, after any env var assignments
        # - NB the BASH_ALIASES[$alname] entry may contain the value of alname, but not
        #   necessarily; e.g. my 'ls-perms' alias simply points to the function 'ls-acl',
        #   and the alias ls-bindings='compgen-match binding'.

        local -i i j k l
        local old_cmd new_cmd

        i=$( array_match -n al_words '^[^=-][^=]*$' ) \
            || { err_msg 3 "no command detected in existing alias words: '${al_words[*]}'"; return; }

        j=$( array_match -n new_words '^[^=-][^=]*$' ) \
            || { err_msg 4 "no command detected in new alias words: '${new_words[*]}'"; return; }

        old_cmd=${al_words[i]}
        new_cmd=${new_words[j]}

        # unless -f is used, ensure the command has not changed
        if [[
            -z ${_f-}
            && $old_cmd != "$new_cmd"
        ]]
        then
            err_msg 5 "old alias command was '$old_cmd', new string has '$new_cmd'"
            return
        fi

        # drop existing al_words elements that match new_words
        # - this ensures args are added at the end, where they usually take precedence
        for k in "${!new_words[@]}"
        do
            # skip the command itself
            [[ $k -eq $j ]] && continue

            # - use array_strrepl here?
            #   just need to deal with possible error condition
            if l=$( array_match -nF -- al_words "${new_words[$k]}" )
            then
                unset "al_words[$l]"
            fi
        done

        # insert new var assns before the command
        [[ $j -gt 0 ]] &&
            array_irepl al_words $i "${new_words[@]:0:$j}" "$old_cmd"

        # add cmd args to the end of the alias
        [[ ${#new_words[@]} -gt $(( j+1 )) ]] &&
            al_words+=( "${new_words[@]:$((j+1))}" )

        # build a new alias string
        # - NB ${#arr[@]} is reliable, even for non-contiguous indices
        #   idcs=${!al_words[@f]} ... or just reindex
        array_reindex al_words

        newal_str=${al_words[0]}

        if [[ ${#al_words[@]} -gt 1 ]]
        then
            local wrd
            for wrd in "${al_words[@]:1}"
            do
                newal_str+=" $wrd"
            done
        fi

        [[ -n $newal_str ]] ||
            { err_msg 9 "empty alias definition (newal_str)"; return; }

        # redefine the alias in the shell's list
        # shellcheck disable=2139
        builtin alias "$alname"="$newal_str"


        # vvv old code
        #     was simpler, but didn't work for some cases

            # local alstr
            # alstr=${BASH_ALIASES[$1]}

            # # do nothing if provided string is already part of the alias
            # if [[ $alstr == *$2* ]]
            # then
            #     return 0

            # # ensure the substitution is possible
            # elif [[ $alstr == *$1* ]]
            # then
            #     # sub, respecting the order: env vars should come first
            #     builtin alias "$1"="${alstr/$1/$2}"

            # else
            #     # complain
            #     type "$1"
            #     return 3
            # fi
    fi
}
