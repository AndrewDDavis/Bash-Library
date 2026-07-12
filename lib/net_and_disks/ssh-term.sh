: """Send TERM_PROGRAM, so tab titles can work properly on ChromeOS Terminal

    Usage: ssh-term [options] user@host

    Note on SSH command and shell logins:

      - When running \`ssh host\`, sshd runs \`bash\` as a login shell.

      - When running \`ssh host cmd\`, sshd runs \`bash -c cmd\`, not as a login shell
        see [this QA for more detail](https://unix.stackexchange.com/q/744263/85414).

      - Running \`exec -l ...\` replaces the non-login shell with a login shell, which
        is preceeded by '-' in \$0, in the insane method that shells have for \"knowing\"
        they're a login shell. Thus, running \`shopt -p | grep login\` will show that
        login is set, and the shell sources /etc/profile and ~/.profile.

      - OTOH, setting BASH_ARGV0 in the command call had the desired effect on \$0, but
        the profile rc files were not read, and shopt shows it's not a login shell.

      - In any case, the MOTD does not display in Ubuntu, but could be replicated by
        adding \`run-parts /etc/update-motd.d/\` before the bash call. Or even just
        replicating the header by sourcing /etc/lsb-release and then running:
        printf \"Welcome to %s (%s %s %s)\\n\" \\
            \"\$DISTRIB_DESCRIPTION\" \"\$( uname -o )\" \"\$( uname -r )\" \"\$( uname -m )\"

      - This indicates that sshd, on user authentication, does more than just drop
        the user into a shell. This may have to do with PAM authentication modules. See
        the login process section of \`man sshd\` for details.
"""

ssh-term() {

    [[ $# -eq 0  || $1 == @(-h|--help) ]] \
        && { dosh -TD; return; }

    local ssh_cmd ssh_exec

    ssh_cmd=$( builtin type -P ssh ) \
        || return 5

    # TODO: deal with passed commands here
    # - check for more than 1 (2) non-option arguments
    # - the lastlog command tries to run on macos

    ssh_exec="
        [ -r /run/motd.dynamic ] &&
            cat /run/motd.dynamic
        [ -r /etc/motd ] &&
            cat /etc/motd
        [ -n \"\$( command -v lastlog )\" ] && {
            _llu=\$( lastlog -u \$USER | tail -1 | tr -s ' ' | cut -d ' ' -f 3,4- )
            _lla=\$( cut -d ' ' -f 1  <<< \"\$_llu\" )
            _lld=\$( cut -d ' ' -f 2- <<< \"\$_llu\" )
            printf 'Last login: %s from %s\n' \"\$_lld\" \"\$_lla\"
            unset _llu _lla _lld
        }
        ${TERM_PROGRAM:+TERM_PROGRAM=\"$TERM_PROGRAM\"} exec -l bash
    "

    # -t requests a TTY, even though we're running a command
    "$ssh_cmd" -t "$@" "$ssh_exec"

    # revert the window title after the ssh command
    # - now done in PS1
    #term_set_title window "@${HOSTNAME%%.*}"
}
