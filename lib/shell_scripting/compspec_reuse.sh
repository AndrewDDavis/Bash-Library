compspec_reuse() {

    : """Re-use the compspec for a command

        Usage: compspec_reuse {parent-cmd} {new-cmd}

        This function is especially useful for wrapper functions and aliases, in which
        most of the arguments and options are identical to the parent command.

        A new on-demand bash-completion file is created in the local user directory:
        ~/.local/share/bash-completion/completions/. This file loads and calls the
        existing completion for the parent command. It may also be manually edited to
        augment it with any new arguments added by the wrapper function.

        Example

          # Re-use the completion spec for systemctl for the wrapper function scw
          # - the completion returned for systemctl is:
          #   complete -F _systemctl systemctl
          # - then the scw completion function would pre-load and call _systemctl
          compspec_reuse systemctl scw
    """

    # TODO:
    # - consider checking the BASH_COMPLETION_USER_DIR variable

    [[ $# -ne 2  || $1 == @(-h|--help) ]] \
        && { docsh -TD; return; }

    local pcmd=$1
    local ncmd=$2
    shift 2

    # the relevant function depends on the version of bash-completion
    local cmp_plfunc
    if declare -F _comp_load >/dev/null
    then
        cmp_plfunc=_comp_load

    elif declare -F __load_completion >/dev/null
    then
        cmp_plfunc=__load_completion

    else
        err_msg 5 "failed to find both _comp_load and __load_completion"
        return
    fi

    # dir and fn for on-demand completion
    local cmp_oddir="$HOME/.local/share/bash-completion/completions"
    local cmp_odfn="$cmp_oddir/$ncmd"

    [[ -d $cmp_oddir ]] \
        || { mkdir -p "$cmp_oddir" || return; }

    [[ ! -e $cmp_odfn ]] \
        || { err_msg 6 "file exists: '$cmp_odfn'"; return; }

    # pre-load completion function for existing command
    "$cmp_plfunc" "$pcmd" \
        || { err_msg 7 "$cmp_plfunc failed for '$pcmd'"; return; }

    # get completion spec
    # - e.g. cmp_spec_words=([0]="complete" [1]="-F" [2]="_systemctl" [3]="systemctl")
    local cmp_spec_words=()
    read -ra cmp_spec_words < <( builtin complete -p "$pcmd" )

    [[ ${cmp_spec_words[-1]} == "$pcmd" ]] \
        || { err_msg 8 "unkown completion spec for '$pcmd': '${cmp_spec_words[*]}'"; return; }

    unset "cmp_spec_words[-1]"

    # ensure -F and capture function name
    local i cmp_spec_func
    for i in "${!cmp_spec_words[@]}"
    do
        if [[ ${cmp_spec_words[i]} == -F ]]
        then
            cmp_spec_func=${cmp_spec_words[i+1]}
            unset "cmp_spec_words[i]" "cmp_spec_words[i+1]"
            break
        fi
    done

    [[ -n $cmp_spec_func ]] \
        || { err_msg 9 "no completion function found for '$pcmd': '${cmp_spec_words[*]}'"; return; }

    # At this point, cmp_spec_words may be only 'complete', but it may also have other
    # options for the complete command.

    # Write out the completion file
    printf '%s\n' "Writing completion script to '$cmp_odfn'"
    cat <<- EOF > "$cmp_odfn"
	_${ncmd}_comp() {

	    COMPREPLY=()

	    # pre-load completions function
	    $cmp_plfunc "$pcmd"

	    # ensure completion spec has the expected form
	    local cmp_spec
	    cmp_spec=\$( builtin complete -p "$pcmd" )

	    [[ \$cmp_spec == complete*"-F $cmp_spec_func"* ]] \\
	        || return 9

	    # call parent completion func
	    # - COMPREPLY will get any completions it finds
	    "$cmp_spec_func" "\$@"

	    # Augment COMPREPLY with new completions below
	    # - Recall you can use COMP_WORDS, COMP_CWORD, and
	    #   posn'l args are 1=cmd, 2=cur_wd, 3=prev_wd.
	    # local cur new_reply
	    # local poss_words=( --foo )
	    # cur=\$2
	    # mapfile -t new_reply < \\
	    #     <( compgen -W "\${poss_words[*]}" -- "\$cur" )
	    # COMPREPLY+=( "\${new_reply[@]}" )

	    return 0
	}
	${cmp_spec_words[*]} -F "_${ncmd}_comp" "$ncmd"
	EOF
}
