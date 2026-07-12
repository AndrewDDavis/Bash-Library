# deps
import_func run_vrb array_strrepl array_pop \
    || return

# aliases
scw-lsmounts() {

    : """list interesting mounts and gvfs services, with headers and styling"

    # use sed to trim the output after the first blank line
    scw -u lsu-all --color 'gvfs-*' '*.mount' \
        | grep -vE '/(proc|sys|dev)/' \
        | sed '/^$/ q'
}

scw-lssocks() {

    : """list sockets from both user and system contexts"

    # user and system contexts give separate lists
    scw -s list-sockets --all \
        | sed '/^$/ q'
    scw -u list-sockets --all \
        | sed '/^$/ q'
}

scw() {

    [[ $# -eq 0  || $1 == @(-h|--help) ]] && {

        : """Run systemctl command lines

        Usage: scw [context] [VAR=value] [command] [arguments ...]

        This function saves typing compared to the full systemctl command, including
        shorter aliases to command names, shorter option names for the Systemd context,
        and automatic invocation of 'sudo' when necessary (i.e. for certain commands
        with the system context, as a non-root user). It also adds the --color option,
        which turns on stylized output from systemd, even if the output is piped to
        another command.

        Valid context arguments:

          -u | --user
          -s | --system (default)
          -r | --runtime
          -g | --global

        The command may be one of systemctl's usual command names or the scw aliases
        shown below. Any further arguments are passed to systemctl after the command,
        as usual. The default command is 'list-units', and the output is usually passed
        to a pager (see SYSTEMD_LESS).

        For many commands, the arguments can include unit names, PIDs, paths, or
        patterns, which are assessed as shell glob expressions. Refer to \`man glob(7)\`
        for details, noting that extended expressions of the form '@(foo|bar)' are not
        supported, but multiple glob patterns may be issued and the results will combine
        as with a logical OR.

        For listing commands (ls, lsf, lst, and variants), scw will expand a pattern
        given as a simple keyword into a wildcard expression of the form '*...*'.

        Notable systemctl commands and scw aliases:

          ( list-unit-files | lsf | find ) [pattern ...]
          : List unit-files. If a pattern is provided, only unit files that match will
            be listed.

          ( list-units | lsu | lsu-all ) [pattern ...]
          : List units matching a glob pattern. This is the default when systemctl is
            run without a command. The 'all' variants show units that are loaded but
            inactive, in addition to the active ones.

          ( list-timers | lst ) [pattern ...]
          : List timer units matching the pattern, and show useful details such as when
            they were last run and when they will fire next.

          list-(automounts|paths|sockets|timers|dependencies) | --state=...
          : List various unit types or states from those that are currently loaded in
            memory.

          status [--full] [pattern ...]
          : With no arguments, shows a tree-view of running services and subprocesses.
            With a pattern, shows unit state, unit file(s), and recent log. Use
            journalctl or jcw for more log output. --full prevents shortening of long
            lines in the output.

          show [pattern ...]
          : Show properties of units, jobs, or the manager itself. This is more
            machine-readable output of the configuration, whereas humans generally want
            'status' or 'cat'. Use --all to include properties that are not set.

          cat UNIT
          : Print unit file and any overrides.

          edit UNIT
          : Edit the override for a unit file, creating it if necessary.

          help UNIT
          : Show man page.

          start, stop, restart UNIT
          : Control the unit's present state.

          enable, disable, mask UNIT
          : Set unit state for next restart. Use --now to also start or stop the unit.

          reload | kill UNIT
          : Tell a unit to reload its config, or send it a signal.

          daemon-reload
          : Reload the Systemd configuration: reruns all generators, reloads all unit
            files, and recreates the dependency tree.

          get-default
          : Show the default target to boot into. Also has a set- version.

          show-environment
          : Show the environment block that is passed to all processes spawned by
            Systemd. Also has set-, import-, and unset- variants.

          log-level [LEVEL] | service-log-level SERVICE [LEVEL]
          : Show or set the current maximum log level of a service or the manager. The
            possible level values are 'emerg', 'alert', 'crit', 'err', 'warning',
            'notice', 'info', and 'debug'.

          log-target [TARGET] | service-log-target SERVICE [TARGET]
          : Show or set the current log destination of the manager. The possible target
            values are 'console' (log to the attached tty), 'console-prefixed' (similar,
            but with expanded prefixes), 'kmsg' (log to the kernel circular log buffer),
            'journal' (log to the journal), 'journal-or-kmsg', 'auto' (the default), and
            'null' (disable log output).

          default | rescue | emergency
          : Enter the specified mode, as in e.g. 'systemctl isolate default.target'.

          halt | poweroff | reboot | soft-reboot [--force] [--when ...]
          : Shut down the system. Halt leaves the hardware powered on. The '--when'
            option can be used schedule a shut down, or cancel it with '--when=cancel'.
            Reboot also has several options related to '--firmware-setup' and
            '--boot-loader-...'. Soft-reboot only reboots user space.

          sleep | suspend | hibernate | hybrid-sleep | suspend-then-hibernate
          : Put system in specified state, where sleep actually chooses a target
            automatically.

        Examples

          # List units (services, mounts, sockets, timers, targets, ...). By default,
          # only units that are active, have pending jobs, or have failed are shown.
          # To include inactive and failed units, use the -all variant.
          scw [-u] [ ls | ls-all ] [--no-pager] [pattern]

          # status and recent log of a unit (from the most recent invocation)
          # - show more output with --full
          # - use journalctl --[user-]unit=... for output from earlier invocations
          scw [-u] status [--full] [pattern | PID]

          # tree-view of dependencies (wanted, required, ...)
          # - shows default.target, unless you specify another, e.g. local-fs.target or
          #   rsync.service.
          # - can show the tree for everything with --all (but that's too busy)
          # - see what must start before a unit with --after
          # - show what depends on a unit with --reverse
          scw [-u] list-dependencies [unit]

          # show all nuances of dependencies for a unit (wanted, requiers, after, ...)
          scw [-u] show <unit>
        """
        docsh -DT
        return
    }

    # Ensure smooth return on errors
    trap '
        trap-err $?
        return
    ' ERR

    trap '
        trap - ERR RETURN
        unset -f _expand_keyword
    ' RETURN


    ### Configure systemctl command call
    local sc_cmdln
    sc_cmdln=( "$( builtin type -P systemctl )" ) \
        || err_msg 9 "systemctl not found"

    # systemd context
    local scctx='system'
    case ${1-} in
        ( -u | --user    ) scctx=user;    shift ;;
        ( -s | --system  ) scctx=system;  shift ;;
        ( -r | --runtime ) scctx=runtime; shift ;;
        ( -g | --global  ) scctx=global;  shift ;;
    esac

    sc_cmdln+=( "--$scctx" )

    # check args for --color
    local scargs=( "$@" )
    shift $#

    # - NB, this array_strrepl call removes the array element and decrements later ones
    if array_strrepl scargs '--color'
    then
        sc_cmdln=( "SYSTEMD_COLORS=1" "${sc_cmdln[@]}" )
    fi

    # check for VAR=value arguments
    local i
    for i in "${!scargs[@]}"
    do
        if [[ ${scargs[i]} == [!-]*=* ]]
        then
            sc_cmdln=( "${scargs[i]}" "${sc_cmdln[@]}" )
        else
            break
        fi
    done
    array_shift scargs $((i-1))

    # systemd command
    # - default is list-units
    # - all valid commands are made up of alnum and '-'
    # - TODO: just use the list of systemctl commands from completion:
    #   add-requires add-wants bind cancel cat condreload condrestart condstop daemon-reexec daemon-reload default disable edit emergency enable exit force-reload freeze get-default halt help hibernate hybrid-sleep import-environment is-active is-enabled is-failed is-system-running isolate kexec kill link list-automounts list-dependencies list-jobs list-machines list-paths list-sockets list-timers list-unit-files list-units log-level log-target mask mount-image poweroff preset preset-all reboot reenable reload reload-or-restart rescue reset-failed restart revert service-log-level service-log-target service-watchdogs set-default set-environment set-property show show-environment soft-reboot start status stop suspend suspend-then-hibernate switch-root thaw try-reload-or-restart try-restart unmask unset-environment whoami
    local sccmd
    if [[ ${#scargs[*]} -eq 0  || ${scargs[0]} == -*  || ${scargs[0]} == *[![:alnum:]-]* ]]
    then
        sccmd=lsu
    else
        sccmd=${scargs[0]}
        array_shift scargs
    fi

    # expand command alias
    case $sccmd in
        ( ls | lsu )
            sc_cmdln+=( list-units )
        ;;
        ( ls-all | lsa | lsu-all | lsua )
            sc_cmdln+=( list-units --all )
        ;;
        ( lsf | lsuf | find )
            sc_cmdln+=( list-unit-files )
        ;;
        ( lst )
            sc_cmdln+=( list-timers )
        ;;
        ( * )
            sc_cmdln+=( "$sccmd" )
        ;;
    esac

    # prepend sudo, if required
    #  - NB, env vars should be set as sudo VAR=value command ...
    #    e.g. for setting SYSTEMD_COLORS=1
    if [[  $scctx == system
        && $( id -u ) -ne 0
        && $sccmd != @(list-*|ls*|find|status)
    ]]
    then
        sc_cmdln=( sudo "${sc_cmdln[@]}" )

        # prompt for password immediately, if necessary
        sudo true \
            || return
    fi


    # pattern match for listing-type commands
    # ( list-* | ls | ls? | ls-all | ls?-all | find )
    local lscmd_ptn='^(list-.*|ls.?(-all)?|find)$'

    if ! [[ $sccmd =~ $lscmd_ptn ]]
    then
        # not a listing-type command
        # - avoid triggering the trap, e.g. on 'status' for a failed service
        "${sc_cmdln[@]}" "${scargs[@]}" \
            || return

    else
        # further arguments should be options and pattern(s)
        local _arg
        for _arg in "${scargs[@]}"
        do
            # expand simple keyword(s) with wildard chars
            # a keyword should:
            # - contain only letters, numbers, dashes, and dots
            # - not be all digits
            # - not generally begin with a dash, except for e.g. -.mount
            if [[  $_arg =~ [^[:alpha:][:digit:].-]
                || $_arg =~ ^[[:digit:]]+$
                || ( $_arg == -*  && $_arg != -.mount )
            ]]
            then
                # not a keyword
                sc_cmdln+=( "$_arg" )

            else
                # keyword found
                sc_cmdln+=( "*${_arg}*" )
            fi
        done

        # return status=1 (i.e. no matches) should not trigger the trap
        local -i rs=0
        run_vrb "${sc_cmdln[@]}" \
            || {
            rs=$?
            (( rs < 2 )) && return $rs
            ( exit $rs )
        }
    fi
}
