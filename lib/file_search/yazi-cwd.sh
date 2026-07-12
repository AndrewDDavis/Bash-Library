if [[ -n $( command -v yazi ) ]]
then
    yz() {
        # yazi-cwd alias
        yazi-cwd "$@"
    }

    yazi-cwd() {

        : """cd to a directory after running yazi"

        local cwd tmpfn

        # ensure clean-up
        trap '
            /bin/rm -f -- "$tmpfn"
            trap - return
        ' RETURN

        # define temp file
        tmpfn=$( mktemp -t "yazi-cwd.XXXXXX" )

        # launch yazi
        yazi "$@" --cwd-file="$tmpfn"

        # check for changed dir, cd, and clean up
        if  cwd=$( cat -- "$tmpfn" ) \
            && [ -n "$cwd" ] \
            && [ "$cwd" != "$PWD" ]
        then
            builtin cd -- "$cwd"
        fi
    }

    # NB, the prompt is modified when dropping to shell from yazi.
    # - this is done in ~/.bashrc, since the prompt logic runs after this file
fi
