# TODO
# - finish the borg-mounting functionality with non-default archive
# - add support for archivemount
# - See also, incorporate ideas from:
#     + [sftpman](https://wiki.archlinux.org/title/Sftpman)
#     + [sshmnt](https://github.com/prurigro/sshmnt/blob/master/sshmnt)
# - note, to mount a USB removable drive, use e.g.
#   udisksctl mount -b /dev/sdc1
# - allow sshfs to pull the connection details from the ~/.ssh/config file, when
#   provided with just a hostname -- this script may need to parse that file
#   too, to get, e.g. a hostname value for display, etc. Or use a ~/.config/mnt
#   config file

# deps
import_func physpath mtdir \
    || return

# aliases for discoverability
alias sshfs-mnt='mnt -s'
alias rclone-mnt='mnt -r'
alias gio-mnt='mnt -g'
alias rmnt="mnt"

: """Mount remote shares, backups, archives, or encrypted files

    Usage: mnt [opts] [-l | destination]

    When a remote destination alias is specified, the default mounting command is
    sshfs, followed by rclone, then gio. The remote files are mounted in directories
    named as /mnt/remote/<dest>.

    The destination may also be a directory. If the directory is a mount point,
    and -u is specified, it will be unmounted. If the directory contains the file
    gocryptfs.conf, it will be mounted using gocryptfs in a directory named as
    /mnt/secure/<dest>.

    Refer to the notes for instructions on how to create the mount-point directories.

    Options

      -s : use sshfs to mount remote share
      -r : use rclone to mount remote share
      -g : use gio to mount remote share
      -b : use borg to mount backup archive
      -c : use gocryptfs to mount secure directory
      -l : list mounts
      -u : unmount
      -v : increase verbosity

    Configured Destinations:

      - squamish
      - nemo
      - nemo-backup
      - nemo-ftp (using rclone)
      - ad-pixel8

    Notes

      - To create the directories to hold the mount-points, use:

          sudo mkdir /mnt/remote
          sudo chmod 0700 /mnt/remote
          sudo setfacl -m u:\"\$USER\":rwx /mnt/remote

        And similarly for /mnt/secure. An ACL is added to give the user rwx permissions,
        so that fuse can manage mounts as the regular user. The user can also create
        and delete files within the directory, and the files are created with typical
        user ownership and permissions. Other users are excluded from using the
        mount-point directories.

      - This function uses /mnt instead of /media or /run/media, as udisksctl does. The
        reasoning is that /mnt is explicitly the domain of the sys-admin, while /media
        and /run/media are not.

      - A user dir in /media such as /media/eric may be given permissions and an
        ACL like:

          USER   root  rwx
          GROUP  root  ---
          mask         r-x
          user   eric  r-x
          other        ---

        The mask limits the permissions of all users and groups other than the
        named users (eric and root in the above example).

      - On mounting to /media instead of /run/media, refer to the [Arch wiki][1].
        Briefly, in recent versions of 'udisks', set UDISKS_FILESYSTEM_SHARED to
        force mounting under /media.

      - The [same Arch wiki page][1] has notes on cleaning stale mountpoints at
        boot using 'tmpfiles.d'.

    [1]: https://wiki.archlinux.org/title/Udisks
"""

mnt() {

    [[ $# -eq 0  || $1 == @(-h|--help) ]] \
        && { docsh -TD; return; }

    # ensure clean return
    trap '
        trap-err $?
        return
    ' ERR

    trap '
        unset -f _chk_mntpt _add_report
        trap - err return
    ' RETURN

    # Command paths
    # - default remote command is first valid of the list
    local -A cmd_pths
    local rcmd_nms=( sshfs rclone gio )
    local a p mcmd

    for a in "${rcmd_nms[@]}"
    do
        if p=$( builtin type -P "$a" )
        then
            cmd_pths[$a]=$p
            [[ -v mcmd ]] \
                || mcmd=$p
        fi
    done

    [[ -v mcmd ]] \
        || err_msg 3 "no valid command in '${rcmd_nms[*]}'"

    # other mounting tools
    for a in gocryptfs borg
    do
        p=$( builtin type -P "$a" ) \
            && cmd_pths[$a]=$p
    done

    # other required utilities
    for a in mount grep sed find fusermount
    do
        cmd_pths[$a]=$( builtin type -P "$a" ) \
            || { err_msg 9 "not found: '$a'"; return; }
    done

    # Defaults
    local action=mount
    local verb=1
    local loc_mntsdir='/mnt/remote'

    # Parse options
    local flag OPTARG OPTIND=1
    while getopts ":grsbcluv" flag
    do
        case $flag in
            ( g | gio ) mcmd=${cmd_pths[gio]} ;;
            ( r | rclone ) mcmd=${cmd_pths[rclone]} ;;
            ( s | sshfs ) mcmd=${cmd_pths[sshfs]} ;;
            ( b | borg )
                mcmd=${cmd_pths[borg]}
                loc_mntsdir='/mnt/borg' ;;
            ( c | gocryptfs )
                mcmd=${cmd_pths[gocryptfs]}
                loc_mntsdir='/mnt/secure' ;;
            ( l ) action=list ;;
            ( u ) action=unmount ;;
            ( v ) verb=2 ;;
            ( \? )
                err_msg 2 "unrecognized option: '-$OPTARG'"
                return ;;
            ( : )
                err_msg 2 "option requires arg: '-$OPTARG'"
                return ;;
        esac
    done
    shift $(( OPTIND-1 ))

    # Capture 'mount' output once to avoid repeated calls
    local mount_out=$( "${cmd_pths[mount]}" )


    ### Just list mounts if requested
    # - list all, instead of adding mcmd to the mount-point name
    if [[ $action == list ]]
    then
        local report

        _add_report() {

            [[ -n $2 ]] \
                || return 0

            report+=$'\n'"${1}:"$'\n'
            report+=$( ${cmd_pths[sed]} 's/^/  /' <<< "$2" )$'\n'
        }

        _add_report 'rclone mounts' "$( "${cmd_pths[grep]}" rclone <<< "$mount_out" || true )"
        _add_report 'sshfs mounts'  "$( "${cmd_pths[grep]}" sshfs <<< "$mount_out" || true )"
        [[ ! -v cmd_pths[gio] ]] \
            || _add_report 'gio reports' "$( "${cmd_pths[gio]}" mount -l )"

        printf '%s\n' "${report:-No mounts found.}"
        return
    fi

    # Default for borg
    if (( $# == 0 )) && [[ $mcmd == */borg ]]
    then
        set -- '::'
    fi

    # Can't go further without remote destination
    [[ $# -gt 0 ]] ||
        err_msg 2 "destination name required unless listing"


    ### Define remote url
    # - rem_host    : FQDN of the destination
    # - rem_user    : login name for destination
    # - rem_path    : initial path on remote host
    # - rem_uri     : URI of the destination for the chosen protocol (e.g. user@host:path)
    # - dest_tag    : name used in the mountpoint to represent the destination
    # - dest_nm     : name, alias, or dir provided by the user to indicate the destination
    # - loc_mntsdir : local dir the holds mount points created by this function
    # - loc_mntpt   : particular mount-point dir to use on this run
    local rem_host rem_user rem_path rem_uri dest_tag loc_mntpt
    local dest_nm=$1
    shift

    case $dest_nm in
        # Setting the host and user are important for sshfs and gio. However, for
        # rclone, this information is only used to construct the name of the
        # mount-point, whereas the actual user and host are pulled from rclone.conf,
        # and the dest_tag should match the remote name (or alias) in that file. If
        # not set, the dest_tag will be taken as the first element of rem_host.
        ( squamish | squam )
            rem_host=squamish.in.spinup.ca
            rem_user=andrew
        ;;
        ( nemo | hud )
            rem_host=nemo.in.spinup.ca
            rem_user=hud
        ;;
        ( nemo-backup )
            rem_host=nemo.in.spinup.ca
            rem_user=hud
            rem_path=/mnt/backup
            dest_tag=nemo-backup
        ;;
        ( nemo-ftp )
            rem_host=nemo.in.spinup.ca
            rem_user=hud
            dest_tag=nemo-ftp

            mcmd=${cmd_pths[rclone]} \
                || err_msg 9 "rclone executable not found"
        ;;
        ( ad-pixel8 )
            # pixel8 phone
            # sshfs pulls option port=8022 from the ~/.ssh/config file
            rem_host=ad-pixel8.in.spinup.ca
            rem_user=u0_a445
        ;;
        ( :: )
            [[ -n ${BORG_REPO-} ]] \
                || { err_msg 5 "BORG_REPO required"; return; }
            dest_tag=${BORG_REPO##*'/'}
            loc_mntpt=${loc_mntsdir}/${dest_tag}
        ;;
        ( * )
            # Not a known alias
            if [[ -d $dest_nm  && $action == unmount ]]
            then
                # asking to unmount a directory
                # - define loc_mntpt and let the unmount code below call fusermount
                # - could also check whether name is abc@def, and get dest_tag from it
                loc_mntpt=$( physpath "$dest_nm" )

                [[ $loc_mntpt == /mnt/secure/* ]] \
                    && loc_mntsdir='/mnt/secure'

            elif [[ -d $dest_nm  && -e ${dest_nm}/gocryptfs.conf ]]
            then
                # gocryptfs directory
                mcmd=${cmd_pths[gocryptfs]}
                loc_mntsdir='/mnt/secure'
                loc_mntpt=${loc_mntsdir}/$( basename "$dest_nm" )

            else
                # suggest list of remotes from rclone.conf
                local rmt_list
                [[ -e ~/.config/rclone/rclone.conf ]] \
                    && rmt_list=$(
                        "${cmd_pths[grep]}" '^\[' ~/.config/rclone/rclone.conf \
                            | /bin/tr -d '[]' \
                            | /bin/tr '\n' ':' \
                            | "${cmd_pths[sed]}" '
                                s/:$//
                                s/:/, /g'
                    )

                err_msg 2 "destination not recognized: '$dest_nm'" \
                    ${rmt_list:+"list from rclone.conf: $rmt_list"}
            fi
        ;;
    esac

    # Ensure mountpoint dir is writable
    [[ -d $loc_mntsdir  && -w $loc_mntsdir ]] \
        || err_msg 9 "not writable: '${loc_mntsdir}'"

    # Define local mount-point dir
    # - loc_mntpt may have been defined using a dir arg above
    [[ -v loc_mntpt ]] || {

        [[ -v dest_tag ]] \
            || dest_tag=${rem_host%%.*}

        loc_mntpt=${loc_mntsdir}/${rem_user}@${dest_tag}
    }

    _chk_mntpt() {

        # ensure mountpoint is an empty dir that exists
        if [[ -L $loc_mntpt ]]
        then
            err_msg 6 "symbolic link at mount-point path: '$loc_mntpt'"
            return

        elif [[ ! -e $loc_mntpt ]]
        then
            /bin/mkdir "$loc_mntpt"

        else
            mtdir "$loc_mntpt" \
                || { err_msg 7 "mount-point is not an empty directory: '$loc_mntpt'"; return; }
        fi
    }


    if  [[ $action == unmount  && $mcmd != */gio ]]
    then
        # rclone, sshfs, gocryptfs, and borg rely on fuse for unmount
        local mnt_ln
        if mnt_ln=$( "${cmd_pths[grep]}" "${loc_mntpt%/}" <<< "$mount_out" )
        then
            # directory is known mountpoint
            [[ "$mnt_ln" == *fuse* ]] \
                || { err_msg 5 "not a fuse mount: '$loc_mntpt'"; return; }

            if ( set -x; "${cmd_pths[fusermount]}" -zu "$loc_mntpt"; )
            then
                /bin/rmdir "$loc_mntpt"

                # report any remaining mounts in mntsdir
                local flist
                flist=$( "${cmd_pths[sed]}" 's/^/  /' < \
                            <( "${cmd_pths[find]}" "$loc_mntsdir" -mindepth 1 -maxdepth 1 -name '[!.]*' ) )

                if [[ -n $flist ]]
                then
                    printf >&2 '%s\n' \
                        "Remaining mount-points:" \
                        "$flist"

                elif [[ $verb -gt 1 ]]
                then
                    printf >&2 '%s\n' \
                        "No additional mount-points found in ${loc_mntsdir}"
                fi
            fi

        elif [[ $loc_mntpt == ${loc_mntsdir}/* ]] \
            && mtdir "$loc_mntpt"
        then
            # stale mount-point
            /bin/rmdir "$loc_mntpt"

        else
            err_msg 6 "not a recognized mount point: '$loc_mntpt'"
            return
        fi

    elif [[ $mcmd == */rclone ]]
    then
        # rclone mounts configured in ~/.config/rclone/rclone.conf
        _chk_mntpt

        # mount options
        local mopts=()
        # - rclone automatically follows symlinks on the dest unless you use then
        #   config option skip_links
        # - monitor output in daemon mode with --log-file and --log-format=pid,...
        # - use '--devname string' to set the device name sent to FUSE for mount
        #   display (default remote:path)
        # - use --allow-root or --allow-other to allow access by sudo or daemons, etc.
        mopts+=( --allow-other )
        # - send to background
        mopts+=( --daemon )
        # - buffer files to disk to support normal file system operations (e.g. seeking in files)
        # - maybe full instead?
        mopts+=( --vfs-cache-mode writes )

        if [[ $dest_tag == *-ftp ]]
        then
            # for nemo
            mopts+=( --ftp-no-check-certificate )
        fi

        (   set -x
            "$mcmd" mount "${mopts[@]}" "$dest_tag": """$loc_mntpt"
        ) \
            && "${cmd_pths[sed]}" >&2 "s:$HOME:~:" \
                <<< "Mounted ${dest_tag} at '${loc_mntpt}'."

    elif [[ $mcmd == */sshfs ]]
    then
        # sshfs: sshfs [user@]host:[dir] mountpoint
        rem_uri=${rem_user}@${rem_host}:${rem_path-}

        _chk_mntpt

        # mount options
        # - refer to man pages for sshfs, ssh, ssh_config, and sftp
        # - consider reconnect,ServerAliveInterval=15,ServerAliveCountMax=3,
        #   per man pages and [answer](https://askubuntu.com/a/716618/52041)
        local moptstr mopts=()

        # map the remote user's UID/GID to the UID/GID of the mounting user
        mopts+=( "idmap=user" )

        # present symlinks on the server as regular files on the client
        # - see also transform_symlinks
        mopts+=( "follow_symlinks" )

        # preferred encryption method
        mopts+=( "Ciphers=aes192-ctr" )

        # prevent errors on renaming across filesystem boundaries
        # - e.g. mv in or out of the mount (per lf docs, and 'man sshfs')
        mopts+=( "workaround=renamexdev" )

        # moptstr from mopts array, as in the join_by() func
        moptstr="${mopts[0]}" &&
            unset "mopts[0]"
        moptstr+=$( printf '%s' "${mopts[@]/#/,}" )

        if ( set -x
            "$mcmd" -o "$moptstr" "$rem_uri" "$loc_mntpt"
        )
        then
            "${cmd_pths[sed]}" >&2 "s:$HOME:~:" \
                <<< "Mounted ${dest_tag} at '${loc_mntpt}'."
            cd "$loc_mntpt"
        fi

    elif [[ $mcmd == */gocryptfs ]]
    then
        _chk_mntpt

        (   set -x
            "$mcmd" "$dest_nm" "$loc_mntpt"
        ) \
            && "${cmd_pths[sed]}" >&2 "s:$HOME:~:" \
                <<< "Mounted ${dest_nm} at '${loc_mntpt}'."

    elif [[ $mcmd == */borg ]]
    then
        # e.g. borg mount -o allow_other --info --last 1 :: /tmp/borgmount
        _chk_mntpt

        local bcmd=( "$mcmd" mount -o allow_other --info )

        if [[ $dest_nm == '::' ]]
        then
            bcmd+=( --last 1 )
        fi

        if run_vrb "${bcmd[@]}" "$dest_nm" "$loc_mntpt"
        then
            printf >&2 '%s\n' "Mounted ${dest_nm} at '${loc_mntpt}'."
            cd "$loc_mntpt"
        fi

    elif [[ $mcmd == */gio ]]
    then
        rem_uri=sftp://${rem_user}@${rem_host}${rem_path:+/${rem_path}}

        if [[ $action == unmount ]]
        then
            # remove symlink and unmount within gio-land
            [[ -L $loc_mntpt ]] &&
                /bin/rm -v "$loc_mntpt"

            (   set -x
                "$mcmd" mount -u "$rem_uri"
            )

        elif [[ $action == mount ]]
        then
            # for GIO, loc_mntpt will be a symlink
            _chk_mntpt
            /bin/rmdir "${loc_mntpt}"

            if ( set -x; "$mcmd" mount "$rem_uri"; )
            then
                /bin/ln -s "/run/user/$UID/gvfs/sftp:host=${rem_host},user=${rem_user}" \
                    "${loc_mntpt}"
                "${cmd_pths[sed]}" >&2 "s:$HOME:~:" \
                    <<< "Mounted ${dest_tag} using ${mcmd}, symlinked to '${loc_mntpt}'."
            fi
        fi
    fi
}
