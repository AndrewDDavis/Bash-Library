chadm() {

    [[ $# -eq 0 || $1 == @(-h|--help) ]] && {

        docsh -TD """Make a file or directory editable by an admin group.

        This is meant to reduce overuse and abuse of sudo, by allowing an admin group to
        edit files without needing elevated priviledges. CAUTION: don't use this on the
        sudoers file itself\!

        Changed permissions and ownership properties:

        - Applies g+rw to files and g+rs to directories, so that group permissions are
          inherited for new files.

        Usage

          chadm [options] _path_ ...

        The _path_ is a regular file or directory to modify. Multiple paths may be
        passed.

        Options

          -g _grp_
          : change group ownership to the indicated one (default 'staff')

          -r
          : change the owner to root (by default, doesn't modify the owner)
        """
        return 0
    }

    # return on error
    trap 'trap-err $?
          return'            ERR
    trap 'trap - ERR RETURN
          unset -f _docs'    RETURN

    # parse args
    local _gr=staff _set_owner=''

    local OPT OPTIND=1
    while getopts "g:r" OPT
    do
        case $OPT in
            ( g ) _gr=$OPTARG ;;
            ( r ) _set_owner=root ;;
        esac
    done
    shift $(( OPTIND - 1 ))  # remove parsed flags and args

    # check group exists on system
    [[ $(uname -s) == Linux ]]  && {
        getent group |
            grep -q "$_gr"  || {
                err_msg 2 "group not found: '$_gr'."
        }
    }

    [[ $# -lt 1 ]] && err_msg 2 "file path arg required"

    # root required
    sudo true  \
        || err_msg 2 "sudo access required"

    # loop over file path(s)
    local _ifn

    for _ifn in "$@"
    do
        [[ -d $_ifn || -f $_ifn ]] || \
            err_msg 2 "path not found: '$_ifn'."

        # change group, and possibly owner
        # - NB, '-c' options to chown and chmod report changes, so no need for run_vrb
        sudo chown -cR "$_set_owner":"$_gr" "$_ifn"

        # change perms
        sudo chmod -cR g+rwX "$_ifn"

        # set setgid bit on dir and subdirs, so newly created files get the group
        # - don't set it on files — that changes the priviledges on file execution
        #printf "\nSetting setgid...\n"
        #find "$_ifn" -type d -exec sudo chmod -c g+s '{}' \;
        local _dfn
        while read -r _dfn
        do
            sudo chmod -c g+s "$_dfn"

        done < <( find "$_ifn" -type d )
    done

    # check user is in group
    [[ ! $( groups ) =~ (^|[[:space:]])${_gr}($|[[:space:]]) ]] && {
        printf '\n'
        err_msg i "the present user is not a member of '${_gr}'.\n"
    }

    # check umask of user
    local _um=$( umask )

    [[ $_um != 00* ]] && {

        printf '\n'
        err_msg i "Umask of present user is $_um ($( umask -S ))"
        err_msg i "Consider umask 0002 or 0007."
        printf '\n'
    }

    return 0
}
