# TODO:
# - introduce -k or --signal option to kill processes or send other signal once
#   you have the list you want; or just leave this to pgrep/pkill
#   -k [sig] : send signal to processes (default TERM, see /usr/bin/kill -L for a list)

# dependencies
import_func run_vrb \
    || return

: """List selected processes and info using ps and pgrep commands

    Usage: ps-pgrep [format-options] < pattern | matching-args >

    Both ps and pgrep from the procps package are used. First, pgrep is called
    using the pattern or matching arguments, to obtain PIDs. Then, 'ps' is called
    to show the formatted process info.

    Any pattern is matched against the whole command line as an extended regular
    expression in a case insensitve manner, as in 'grep -Ei'. To match only a
    command name, use the -C option or an anchored regex pattern, e.g. '^pat',
    '^pat( |$)', or '\bpat\b'.

    Other pgrep matching options may be used instead of, or in addition to, a
    pattern. These include:

      -x           : require exact match to search pattern
      -o / -n      : select only the oldest or newest matching process
                     (most/least recently started)
      -g / -u / -P : match only a process group, user, PPID, runstate, etc.

    By default, the call to 'ps' uses the -f flag to produce a full-format
    listing. This can be changed using the following output format options
    interpreted by ps-pgrep:

      --ids : show PPID, PGID, and UID along with PID and S
      --res : show resources (%CPU and RSS in kB), elapesed time since start,
              and sort by RSS
      --hie : show process hierarchy using indentation
      --for : show process hierarchy using ASCII art (forest)
      --comm : print command name instead of full command-line
      --col=<col> : add output column(s); refer to STANDARD FORMAT SPECIFIERS
                    in the ps manpage

    Other Notes:

    - The output is unsorted by default. The --sort=key option is supported
      by ps-pgrep, and will be passed to ps.
    - The output is truncated to the terminal width by default. To see any
      truncated text, it is recommended to pipe the output to less, then use the
      arrow keys.
    - Only Linux ps (procps) is supported, as the BSD ps syntax is different.
"""

ps-pgrep() {

    [[ $# -eq 0  || $1 == @(-h|--help) ]] \
        && { docsh -TD; return; }

    trap 'return' ERR

    trap '
        unset -f _parse_args _cmd_chk
        trap - err return
    ' RETURN

    _parse_args() {

        trap '
            unset -f _ocol_add
            trap - return
        ' RETURN

        _ocol_add() {

            # add new element to ocols string, if unique; e.g. pid,ppid,command
            local oc
            for oc in "$@"
            do
                if [[ ! -v ocols ]]
                then
                    ocols=$oc

                elif [[ ! $ocols =~ (^|,)"$oc"($|,) ]]
                then
                    ocols+=",$oc"
                fi
            done
        }

        # options
        local n _C ocols comm
        local flag OPTARG OPTIND=1
        while getopts ':C-:' flag
        do
            longopts ':ids res hie for comm col: sort:' flag "$@"
            case $flag in
                ( ids )
                    _ocol_add pid ppid pgid uid s
                    ;;
                ( res )
                    _ocol_add pid s etime '%cpu' rss
                    ps_opts+=( --sort=rss )
                    ;;
                ( hie )
                    _ocol_add pid ppid pgid s
                    ps_opts+=( -H )
                    ;;
                ( for )
                    _ocol_add pid ppid pgid s
                    ps_opts+=( --forest )
                    ;;
                ( comm )
                    comm=1
                    ;;
                ( col )
                    _ocol_add "$OPTARG"
                    ;;
                ( sort )
                    ps_opts+=( --sort="$OPTARG" )
                    ;;
                ( C )
                    _C=1
                    ;;
                ( \? )
                    # short or long option destined for pgrep
                    n=$(( OPTIND-1 ))
                    if (( n > 0 )) && [[ ${!n} == @(-|--)"$OPTARG" ]]
                    then
                        # e.g. -x or --foo, OPTIND was incremented
                        pgrep_args+=( "${!n}" )

                    elif [[ ${!OPTIND} == -"${OPTARG}"* ]]
                    then
                        # e.g. -xyz, OPTIND did not advance and OPTARG=x
                        pgrep_args+=( "${!OPTIND}" )

                        # advance OPTIND: if we try to do it manually, getopts
                        # will set the OPTARG to 'y' anyway; so just call getops
                        # again to advance its internal counter, until it advances
                        # OPTIND
                        while (( OPTIND == (n+1) ))
                        do
                            getopts ':' flag
                        done
                        unset OPTARG
                    else
                        err_msg 3 "unexpected argument situation:" \
                            "$( declare -p OPTIND OPTARG )"
                        return
                    fi
                ;;
            esac
        done
        shift $(( OPTIND-1 ))

        # defaults
        # - NB, was using -A with pgrep, but I don't think this is relevant
        #   without sudo, and it filters out the current shell session and its
        #   ancestors! Refer to diff <(pgrep -a .) <(pgrep -Aa .).
        if [[ -v _C ]]
        then
            pgrep_args=( '-i' '-d,' "${pgrep_args[@]}" )
        else
            pgrep_args=( '-if' '-d,' "${pgrep_args[@]}" )
        fi

        if [[ -v ocols ]]
        then
            [[ -v comm ]] \
                && ocols+=,comm \
                || ocols+=,command

            ps_opts=( -o "${ocols[@]}" "${ps_opts[@]}" )
        else
            [[ -v comm ]] \
                && ps_opts=( -o 'uname=UID,pid,ppid,c,stime,tname,time,comm' ) \
                || ps_opts=( '-f' )
        fi

        # positional args, if any
        pgrep_args+=( "$@" )
        shift $#
    }

    _cmd_chk() {

        ps_cmd=$( builtin type -P ps ) \
            || return 9

        pgrep_cmd=$( builtin type -P pgrep ) \
            || return 9

        local _ps_vers
        if ! _ps_vers=$( "$ps_cmd" --version 2>/dev/null ) \
            || ! [[ $_ps_vers == *procps-ng* ]]
        then
            err_msg 5 "ps version not supported"
            return
        fi

        # limit display width, unless output redirected
        # - necessary b/c ps output is redirected below
        if [[ -t 1 && -v COLUMNS ]]
        then
            ps_opts+=( --cols="$COLUMNS" )
        fi
    }

    # defaults and args
    local pgrep_args=() ps_opts=()
    _parse_args "$@"
    shift $#

    # check for supported ps and pgrep
    local ps_cmd pgrep_cmd
    _cmd_chk

    # get PIDs and report using the output format
    # - this uses 'ps -p' to select processes by PID
    # - NB, pgrep exits with code 1 if nothing found, or >1 on error
    local pids ps_out ec

    if pids=$( run_vrb -- "$pgrep_cmd" "${pgrep_args[@]}" )
    then
        ps_out=$( run_vrb -- "$ps_cmd" "${ps_opts[@]}" -p "$pids" )
        printf >&2 '\n'
        printf '%s\n' "$ps_out"
    else
        ec=$?
        if (( ec == 1 ))
        then
            printf >&2 '\n%s\n' "No matches."
        else
            return $ec
        fi
    fi
}
