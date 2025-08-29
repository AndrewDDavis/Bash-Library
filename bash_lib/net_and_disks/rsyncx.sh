# deps
import_func array_match std-args \
    || return

alias rsync-local='rsyncx --local'
alias rsync-remote='rsyncx --remote'
alias rsync-check='rsyncx --diff'

: """Wrapper function for rsync with useful modes

    Usage: rsyncx [rsync-opts] SRC [... DEST]

    This wrapper function runs rsync with a set of options that are sensible in most
    situations, and provides a few additional options for common situations.
    Otherwise, this function passes all of its arguments unchanged to rsync. Rsync
    requires that remote source or destination names include a colon, as in
    [user@]host:dir. If DEST is omitted, the contents of SRC are listed.

    By default, rsyncx adds the flags -rlpt and -AXU to the command-line. These are
    a sensible starting point for almost any transfer. However, they can be
    selectively negated, like all other options, by using e.g. --no-t. The -N
    (--crtimes) option is not issued, since it's not available with Debian-compiled
    rsync at the time of writing.

    Beyond -rlpt, the remaining flags turned on by 'rsync -a' are -goD. Rsyncx only
    adds these to the command when all SRC and DEST are local. In practice, these
    flags are ignored by rsync anyway (partially for -g) unless running as super-
    user on the receiving end, or using --super.

    While rsync only detects whether any SRC or DEST are remote by matching the
    required colon in the name, rsyncx additionally detects locally-mounted remote
    filesystems using SSHfs, rclone, or gvfs (e.g. GIO vfs mounts created by
    Nautilus). This avoids permissions errors for such transfers, as rsync would
    try and fail to apply -g.

    In addition, rsyncx applies either the --local or --remote flag based on the
    auto-detection of remote SRC and DEST, unless one is explicitly included on the
    command-line. These are described below, along with the additional flags that
    rsyncx makes available.

      --local
      : This adds -H to the defaults, to preserve hard-links.

      --remote
      : Adds -z and --partial to the defaults. This compresses data in transit, and
        preserves partially transferred files. NB, rsync has a good default list of
        compression exclusions. The --info=progress2 option is also added to show
        overall transfer progress.

      --remote-mount
      : Some of the --remote options can also be useful when transferring to or from
        local directories that are actually a remote filesystem mount, such as
        through SSHfs. This flag sets the --partial and --info=progress2 flags, and
        prevents -goD from being added, to avoid permissions errors. When neither
        of the --local or --remote flags are used, rsyncx will attempt to detect
        a remote mount and set --remote-mount automatically.

      --diff
      : Check for differences among files, but don't make any transfers. In addition
        to the defaults, this adds: -nci --delete. Refer to the notes on -i below:
        any files that are only on DEST will be marked with *deleting, and any files
        that are only on SRC will be marked with xx+++++++++.

      --rsbak
      : Create backup files, using the options: --backup --suffix='.rsbak'. Consider
        also the --backup-dir option.

      --mv
      : Simulate moving files. This adds --remove-source-files, and --info=remove to
        print an info line for each removed file. After a successful transfer, the
        source files are removed, but empty directories may remain. This can depend
        on interactions with filters, etc, thus pruning empty directories is not
        attempted. Suggested commands to prune the dirs are printed.

    Info Reporting Options

    By default, rsync is quiet. To show some basic info including a listing of
    changed files, -v can be used to turn on a sensible set of --info flags. Using
    -vv shows very detailed information about the transfer and the application of
    the filter rules.

    This function adds --info=del,stats to the command-line when -v is not used.
    This prints file deletions and a short data transfer summary. -h is also added
    for human readable data units.

    Use -i to print a summary line for each changed file. Use -ii to also print a
    line for unchanged files. Refer to the rsync manpage under --itemize-changes to
    decode the summary line. Briefly:

      - If a file is to be removed, the summary line is * followed by the
        word deleting. Otherwise, the first char is the update type. It may be < or
        > for files sent and received, . for a file with unchanged content, or c for
        a directory to be created.

      - The second char is the file type, which may be f (file), d (dir), L (symlink),
        D (device), or S (special).

      - The remaining characters are '+' for a newly created file. Otherwise, any that
        are not '.' indicate an attribute that will be updated, or why the file is being
        transferred, e.g. c (checksum), s (size), t (mod time), u (access time),
        n (create time), b (u + n), p (permissions), o (owner),
        g (group), a (ACL), x (extended attribute), etc.

    Issue '--info=help' to print the rsync's info flag options that may be used. The
    following options are recommended to achieve the noted effects. Note that
    explicit --info settings always override the implied settings of e.g. -v or
    --progress:

      --info=name0
      : Suppress the file listing when using -v or -vv.

      --info=name2 or -vv
      : Print a line for each unchanged file.

      --info=skip or -vv
      : Print a line for each skipped file when using -u (--update).

      --info=progress2
      : Show overall transfer progress (added with --remote)

      --stats or --info=stats2
      : Print a detailed file transfer summary.

      --debug=filter or -vv
      : Print the results of applied filter rules.

    Thus, adding -ni to your existing command line is an excellent way to get a
    detailed picture of the changes that will occur, before affecting any files. If
    using -nii with -u, rsyncx also adds --info=skip to get a complete picture.

    Filter Rules

    Rsync builds an ordered list of filter rules as specified on the command-line
    and found in relevant files. The default is for all files within the transfer
    root to be included.

    This function honours the filter rules found in '~/.config/rsync/default.rules',
    if that file exists. They are applied using the merge-files syntax for the
    '--filter' option, and are intended to exclude machine-specific hidden files,
    such as '.DS_Store' and lock files. To clear the filter list, use: -f'!' on the
    command line.

    To exclude files for a single transfer, the --exclude=PATTERN option may be
    used, which is equivalent to a filter rule of -f'- PATTERN'. The patterns
    generally follow globbing rules as in other similar tools. Refer to the PATTERN
    MATCHING RULES section of the rsync manpage for details and examples.

    To include only certain files in a transfer, include rules are needed for the
    file and any parent directories within the transfer root. Then a trailing
    exclusion rule that matches all files would be specified, e.g.:

      -f'+ x/' -f'+ x/y/' -f'+ x/y/file.txt' -f'- *' x host:/tmp/

    Exclude rules both hide files on the sending side and protect files on the
    receiving side. Similarly, include rules both show (or expose) files on the
    sending side, and risk files on the receiving side.

    The option -F may be used apply per-directory filter rules found in files
    named '.rsync-filter'. With -F, the .rsync-filter files may be found in parent
    directories of the transfer root, as well as its subdirectories. Refer to the
    MERGE-FILE FILTER RULES section of the rsync manpage.
"""

rsyncx() {

    [[ $# -eq 0  || $1 == @(-h|--help) ]] \
        && { docsh -TD; return; }

    # clean up
    trap '
        unset -f _chk_rem _get_fstype
        trap - return
    ' RETURN

    # rsync path
    local rs_cmd
    rs_cmd=( "$( builtin type -P rsync )" ) \
        || return 5

    # default filtering rules
    [[ -r ~/.config/rsync/default.rules ]] \
        && rs_cmd+=( -f ". ${HOME}/.config/rsync/default.rules" )

    # Run std-args to parse rsync args (makes _stdopts)
    # - specify short and long opts that require an arg
    local opt_args pos_args
    so='MBeT@f'
    lo="address bwlimit config dparam port log-file log-file-format sockopts include-from \
        files-from copy-as address port sockopts outbuf remote-option out-format log-file \
        log-file-format password-file early-input bwlimit stop-after stop-at write-batch \
        only-write-batch read-batch protocol iconv checksum-seed info debug stderr \
        backup-dir suffix chmod checksum-choice block-size rsh rsync-path max-delete \
        max-size min-size max-alloc partial-dir usermap groupmap chown timeout contimeout \
        modify-window temp-dir compare-dest copy-dest link-dest compress-choice \
        compress-level skip-compress filter exclude exclude-from include"

    std-args opt_args pos_args "$so" "$lo" -- "$@" \
        || return

    # check for -v or -vv, otherwise print minimal info
    array_match -- _stdopts '-v' \
        || rs_cmd+=( --info='del,stats' )

    # check for -nii with -u
    array_match -- opt_args '-nii' \
        && array_match -- _stdopts '-u|--update' \
        && rs_cmd+=( --info=skip )

    # detect dry-run
    local _dr
    array_match -- _stdopts '-n|--dry-run|--diff' \
        && _dr=1

    # Detect local vs remote transfer, if not specified
    local _rem
    if array_match -- _stdopts '--remote'
    then
        _rem=":"

    elif array_match -- _stdopts '--remote-mount'
    then
        _rem="mount"

    elif ! array_match -- _stdopts '--local'
    then
        # - the only pos_args are SRC(s) and DEST
        local n s srcs dest
        n=${#pos_args[@]}

        {
            # - define df_cmd to check for remote mounted local fs, e.g. sshfs fuse mount:
            #   findmnt -n -o FSTYPE -M /mnt/remote/andrew@squamish
            #   ^^^ from util-linux package
            #   df -h /mnt/remote/andrew@squamish/Media --output=fstype
            #   ^^^ gnu coreutils df only, can be installed on macOS through homebrew
            # - use df from GNU coreutils
            local gnu_df
            if [[ -n $( command -v gdf ) ]]
            then
                gnu_df=$( builtin type -P gdf )

            elif [[ $( command df --version 2>/dev/null ) == *GNU\ coreutils* ]]
            then
                gnu_df=$( builtin type -P df )
            fi

            _get_fstype() {

                if [[ -v gnu_df ]]
                then
                    "$gnu_df" -h "$1" --output=fstype | tail -n1
                else
                    # macOS: get mnt-pnt from df, then parse the output of mount
                    # - e.g. /dev/disk2s2 ... 0% /Volumes/Files
                    # - then do a regex match on /Volumes/Files (hfs, ...
                    local mp rgx nl=$'\n'
                    mp=$( command df "$1" | tail -n1 )
                    mp=${mp## /}
                    rgx="(^|${nl})[^${nl}]+ ${mp} \(([^,]+)"
                    [[ $( command mount ) =~ $rgx ]] \
                        || return
                    printf '%s\n' "${BASH_REMATCH[2]}"
                fi
            }

            _chk_rem() {
                # check whether arg is remote or local
                local fstype
                if [[ $1 == *:* ]]
                then
                    printf '%s\n' ":"
                    return 0

                elif fstype=$( _get_fstype "$1" )
                then
                    # e.g. fstype=fuse.sshfs or btrfs or hfs
                    [[ $fstype == fuse.@(sshfs|rclone|gvfsd-fuse) ]] \
                        && { printf '%s\n' "$fstype"; return 0; }
                fi

                # assume local if not returned yet
                return 1
            }
        }

        if (( n == 1 ))
        then
            # only source (listing)
            srcs=( "${pos_args[@]:0:1}" )

        else
            # last arg is dest, even with --local-only
            dest="${pos_args[-1]}"
            unset 'pos_args[-1]'
            srcs=( "${pos_args[@]}" )

            _rem=$( _chk_rem "$dest" )
        fi

        if [[ ${_rem-} != ":" ]]
        then
            # NB, rsync only allows one side to be remote, but I don't think that
            # applies to locally-mounted remote filesystems
            for s in "${srcs[@]}"
            do
                s=$( _chk_rem "$s" ) \
                    && { _rem=$s; break; }
            done
        fi

        if [[ ${_rem-} == ":" ]]
        then
            set -- --remote "$@"
        elif [[ -n ${_rem-} ]]
        then
            set -- --remote-mount "$@"
        fi
        # not setting --local here, since we're not 100% sure
    fi

    # general purpose, sensible default for most file syncing situations
    # - NB, -s (--protect-args) no longer necessary as of rsync 3.2.4
    # - NB, rsync on Debian testing (trixie) doesn't have -N
    rs_cmd+=( -h -rlX -pA -tU )

    # don't add goD by default
    # - especially for transfers that involve locally mounted remote files. Doing so may
    #   cause rsync to return with a permission error, because it can't set the group,
    #   even when running without sudo.
    [[ -n ${_rem-} ]] \
        || rs_cmd+=( -goD )

    # check for rsyncx options
    local w _mv rs_args=()
    for w in "$@"
    do
        case $w in
            ( --diff )   rs_args+=( -nci --delete ) ;;
            ( --local )  rs_args+=( -H ) ;;
            ( --remote ) rs_args+=( --partial -z --info=progress2 ) ;;
            ( --remote-mount ) rs_args+=( --partial --info=progress2 ) ;;
            ( --rsbak )  rs_args+=( --backup --suffix='.rsbak' ) ;;
            ( --mv )     rs_args+=( --remove-source-files --info=remove ); _mv=1 ;;
            ( * )
                rs_args+=( "$w" )
            ;;
        esac
        shift
    done

    # run rsync
    "${rs_cmd[@]}" "${rs_args[@]}" \
        || { err_msg $? "rsync error, command was:" "${rs_cmd[*]} ${rs_args[*]}"; return; }


    if [[ -v _mv  && ! -v _dr ]]
    then
        # suggest pruning empty dirs after mv
        printf >&2 '%s\n' '' \
            "Suggested command to prune empty dirs:" \
            "  $( builtin type -P find ) SRC_ROOT -type d -empty -print -delete" ''
    fi
}
