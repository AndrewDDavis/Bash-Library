### Tar Archives Notes:
#
# - when extracting archives that have symlinks containing '..' in their paths, tar is
#   very careful with the extraction, and does some checks to ensure nothing malicious
#   is happening. This can add a lot of extra time. As [noted](https://mort.coffee/home/tar),
#   use the -P option to disable the security checks and speed up the process if you
#   trust the archive.
#
# - a project that addresses tar's major shortcomings is [dar](https://github.com/Edrusb/DAR)
#   (e.g. compression within the archive, archive index, checksum, encryption, ...), and
#   still retains nice features from tar (e.g. transfer over ssh).
#
# - another nice alternative is tpxz archives... See my notes file.

# TODO:
# - tarc: consider an option (-h) for generating an md5 for the archive
# - create a function for appending to a tgz archive; part of tarc?
# - using tarc -maf foo ... shouldn't override the usual behaviour of tar -a,
#    it's too confusing.
# - NB, the progress meter from tar-cz has been incorporated into tarc

tarc() (

    : """Copy or move files to a tar archive.

    Usage: tarc [opts] [--] [tar-opts] path1 [path2 ...]

    This is a wrapper function for quickly creating or adding to a tar archive,
    and optionally removing the source files to simulate a move operation.
    Although most arguments are passed on to tar, tarc works differently in the
    following ways:

    - If only non-option arguments are issued, or the -a option is used
      (see below), tarc will create an archive at the same path as
      the last argument, with an added file extension (default .tgz). If the
      intended archive name already exists, the operation will be aborted,
      unless -r or -u are in the initial tarc options (see operation
      modes below).

    - tarc excludes files matching patterns in ~/.config/zip/zip_xlist,
      if that file exists. E.g., patterns may match .DS_Store.

    Options understood by tarc

      -a <ext>
      : Explicitly enable auto-generation of the archive name from the last
        command line argument, and specify a filename extension to use for
        the archive (e.g. .txz).

      -m
      : Remove source files given on the command line after successfully
        adding them to the archive. See further notes below.

      -v
      : Turn on verbose mode: prints files added to the archive and removed
        files and dirs when move (-m) is enabled.

      -c / -r / -u
      : Create (default), append, or update archive. See operation modes below.

    tarc expects the options it understands to come first. When it encounters an
    unrecognized option, it passes all remaining options to tar. Use '--' on the
    command line to ensure that tarc will pass any further options to tar without
    attempting to interpret them.

    Examples

      tarc dir1
      : tar and zip a directory into a .tgz archive

      tarc -caf dir1.txz dir1
      : same, but with xz compression (auto-detected):

      tarc -v -I pbzip2 dir
      : tar verbosely with parallel bzip2 compression:


    Tar Operation Modes

      tar -c [-f ARCHIVE] [OPTIONS] [FILE...]
      : Create new archive, overwriting an existing one.

      tar -r [-f ARCHIVE] [OPTIONS] [FILE...]
      : Like -c, but append files to the end of an archive (only for uncompressed
        archives stored in regular files).

      tar -u [-f ARCHIVE] [OPTIONS] [FILE...]
      : Like -r, but only append files if they are newer than the copy in the archive.

      tar -t [-f ARCHIVE] [OPTIONS] [MEMBER...]
      : List the contents of an archive.

      tar -x [-f ARCHIVE] [OPTIONS] [MEMBER...]
      : Extract files from an archive.

      tar --test-label [--file ARCHIVE] [OPTIONS] [LABEL...]
      : Test archive volume label and exit (GNU only).

      tar --delete [--file ARCHIVE] [OPTIONS] [MEMBER...]
      : Delete from the archive (GNU only).

      tar -A [OPTIONS] -f ARCHIVE ARCHIVE...
      : Append archive(s) to the end of another archive (GNU only, and see caveats in
        man page).

      tar -d [-f ARCHIVE] [OPTIONS] [FILE...]
      : Find differences between archive and file system (GNU only).


    Notes on Move (-m option)

      - Using -m has several differences compared to using --remove-files with GNU tar:

          + GNU tar removes the files during program operation. Thus, if a later
            command-line file argument does not exist, tar exits, but has already
            removed the files specified earlier on the command line.

          + This function is more conservative, and only removes files after a
            successful run is completed. The trade-off is that it requires enough disk
            space to create the full archive before any data is deleted.

          + GNU tar also fails when there are excluded files, because it can't rmdir.

      - To track the added files, this function turns on the -v argument to tar and
        captures the output to track added files for later removal. Thus, to see verbose
        output to the terminal when using -m, issue the -v option earlier on the
        command-line.

    Other Notes

    - Exclude files by glob pattern using '--exclude=PATTERN'. Recent GNU and
      BSD tar also have --exclude-vcs, which excludes e.g. '.git' dirs.

    - Using -C <dir> : Change to DIR before performing operations. This option
      is order-sensitive, i.e. it affects all options that follow. In c and r
      mode, changes dir before adding the following files. In x mode, changes
      dir before extracting entries from the archive.

	- The type of compression may be specified in several ways:

	  1. Using the -a and -f flags, add an appropriate extension to the output
	     filename, such as:
	     - tgz for zip compression
	     - tbz for bzip2 compression
	     - txz for xz compression
	     - tzstd for zstd compression

	  2. Specify the compression type in the options, e.g.: '--gzip' (or '-z'),
	     '--bzip2' (or '-j'), '--xz' (or -J), or '--zstd'.

	  3. Both BSD and GNU tar take the '--use-compress-program' option, to
	     directly specify an arbitray compression program, e.g.:
	     + pigz for parallel gzip compression
	     + bzip2 for bzip compression
	     + pbzip2 for parallel bzip compression
	     On GNU tar, the program may contain command-line arguments, but this
	     does not seem to work on BSD tar.

	  Options to the compression program may be passed using --options, e.g.:
	  --options='compression-level=9'.
    """

	[[ $# -eq 0 || $1 == @(-h|--help) ]] &&
	    { docsh -TD; return; }

    # trap ERR to cleanly return on errors
    # shellcheck disable=SC2154
    trap '
        s=$?
        printf "%15s %s\n" \
            "$FUNCNAME returning:" \
            "status $s at l. ${BASH_LINENO[0]}," \
            " " "command is $BASH_COMMAND"
        return $s
    ' ERR

    trap '
        trap - return err
    ' RETURN

    # Parse args
    # - note default getopts behaviour:
    #     + breaks on -- by default and advances OPTIND
    #     + breaks on non-option arg and doesn't advance OPTIND
    local _append _mv _verb tar_opts=()

    local flag OPTARG OPTIND=1
    while getopts ":cruma:v" flag
    do
        case $flag in
        ( c )
            _append=False
            tar_opts+=( -c )
        ;;
        ( r | u )
            _append=True
            tar_opts+=( -$flag )
        ;;
        ( m )
            _mv=True
            [[ -z ${_verb-} ]] && tar_opts+=( -v )
        ;;
        ( a )
            _ofx=${OPTARG#.}
        ;;
        ( v )
            _verb="-v"
            [[ -z ${_mv-} ]] && tar_opts+=( -v )
        ;;
        ( \? )
            # ensure opts for tar are passed through
            (( OPTIND -= 1 ))
            break
        ;;
        ( : )
            err_msg 2 "missing argument for -$OPTARG"
            return
        esac
    done
    shift $(( OPTIND-1 ))

    _chk_tarv() {
        # GNU tar or BSD tar
        # - tar command to use (tar, gtar, or bsdtar)
        local tar_cmd="tar" tar_type tar_vstr tar_vers tar_vout

        # - Prefer GNU since bsdtar doesn't take options to the compression program
        # - Homebrew installs Gnu tar as gtar
        [[ -n $( command -v gtar ) ]] &&
            tar_cmd="gtar"

        # ensure command is on path
        tar_cmd=$( builtin type -P "$tar_cmd" ) \
            || return 2

        # Test tar version
        # - BSD tar: bsdtar (on both Linux and macOS) 3.7.2 (Linux), 2.8.3 (macOS)
        # - GNU tar: (GNU tar) 1.35
        tar_vstr=$( "$tar_cmd" --version | head -n1 )

        if command grep -q 'bsdtar' <<< "$tar_vstr"
        then
            tar_type=bsd
            tar_vers=$( cut -d' ' -f2 <<< "$tar_vstr" )
            tar_vout="BSD tar ${tar_vers}"

            [[ ${tar_vers:0:1} -lt 3 ]] && {
                printf >&2 '%s\n' "Warning, older BSD tar version: $tar_vers"
            }

        elif command grep -q 'GNU tar' <<< "$tar_vstr"
        then
            tar_type=gnu
            tar_vers=$( cut -d' ' -f4 <<< "$tar_vstr" )
            tar_vout="GNU tar ${tar_vers}"

        else
            err_msg w "unknown tar version string:" "$tar_vstr"
        fi

        [[ -n ${tar_type-} ]] &&
            printf >&2 ' + %s\n' "$tar_vout"
    }

    _chk_tarv


    # Introduce archive name if needed
    # - this is only simple for 1 non-option arg, otherwise you would need to
    #   parse the args as tar does...
    # TODO: use std-args here for tar


    # - count option and non-option args
    n_opts=$( printf '%s\0' "$@" \
                | { command grep -Ezc '^-' || true; } )
    n_args=$(( $# - n_opts ))

    if [[ $n_args -eq 0 ]]
    then
        err_msg 2 "file args required"

    elif [[ $n_opts -eq 0 || -n $_ofx ]]
    then
        # create by default
        [[ -z ${_append-} ]] &&
            tar_opts+=( -c )

        # define archive name
        # last arg must be a source path
        ifn=${@:(-1)}
        ofn=${ifn%/}.${_ofx:-tgz}

        # check for existing file or permissions error
        # - a writable empty file can be used to get around lack of create permission
        local of_sz
        [[ -e $ofn ]] &&
            of_sz=$( stat -c'%s' "$ofn" )

        if [[ ${_append-} != True  && -e $ofn ]]
        then
            [[ $of_sz -eq 0 ]] ||
                err_msg 3 "outfile exists: $ofn"
        fi

        /bin/touch "$ofn" 2>/dev/null \
            || err_msg 4 "no permissions for $ofn"

        tar_opts+=( -af "$ofn" )
    fi


    # Exclude annoying files (e.g. .DS_Store) if exclude file found
    # - works with GNU tar (Linux) and BSD tar (macOS)
    # - --exclude-from=FILE is also cross-platform, but not on older bsdtar
    xlist="$HOME/.config/zip/zip_xlist"
    [[ -s $xlist ]] &&
        tar_opts+=( -X "$xlist" )


    # Echo tar command line, but not too verbose
    printf >&2 ' + %s' "$tar_cmd"

    _prev_arg=''
    for arg in "${tar_opts[@]}" "$@"
    do
        if [[ $_prev_arg == -X ]]
        then
            printf >&2 ' %s' ".../zip_xlist"
        else
            printf >&2 ' %s' "$arg"
        fi
        _prev_arg=$arg
    done
    printf >&2 '\n'


    # Run tar
    # - no need to test return status, errtrap takes care of it
    # - previously used separate tar and zip, e.g.:
    #   tar -cf - "$ifn" | $zp ${zo-} > "$ofn"
    if [[ ${tar_type-} == gnu ]]
    then

        # Show totals on STDERR at end
        tar_opts+=( --totals )

        # Print a crude progress meter on STDERR
        # - calculate input data size, and calc 2% for checkpoints
        # - du calculates total number of 1K blocks
        # - this assumes last arg is source file name
        local data_sz data_sz_h cp_sz
        data_sz=$( du -sk --apparent-size "${@:(-1)}" \
                    | cut -f 1 )
        cp_sz=$( bc <<< "scale=0; ${data_sz}/50" )

        # show est. size in human units
        data_sz_h=$( numfmt --from-unit=1024 --to=iec "$data_sz" )
        printf >&2 '%s\n' \
            "Estimated data size: $data_sz_h"

        # configure checkpoint print format
        # - ref man for --checkpoint:
        #   https://www.gnu.org/software/tar/manual/html_section/checkpoints.html
        tar_opts+=(
            --record-size=1K
            --checkpoint="$cp_sz"
            --checkpoint-action=ttyout='%{%Y-%m-%d %H:%M:%S}t (%d sec): %uK read, %T%*\r'
        )

        # other output ideas:
        #_opts+=( --record-size=1K --checkpoint="$chkpt" --checkpoint-action="ttyout=>" )
        #printf '%s\n' "Estimated: [==================================================]"
        #printf '%s' "Progess:   ["
        #printf '%s\n' "]"


        # GNU tar outputs file list on stdout
        tar_msg=$( "$tar_cmd" "${tar_opts[@]}" "$@" )

    else
        # BSD/MacOS Tar is different:
        # - no --remove-files, capture verbose output to remove files separately
        # - doesn't allow -r for zipped archives
        # - -I has a different meaning

        # BSD tar outputs file list on stderr, shuffle the FDs
        {
            tar_msg=$( "$tar_cmd" "${tar_opts[@]}" "$@" 2>&1 1>&3 3>&- )

        } 3>&1
    fi


    if [[ -n ${_mv-} ]]
    then
        # Print tar output only if -v was given on CL
        [[ -n ${_verb-} ]] && printf '%s\n' "$tar_msg"

        # Process list of added files and dirs
        d_fns=()

        while IFS='' read -r fn
        do
            # save dirs for later
            [[ -d $fn ]] && {
                d_fns+=( "${fn%/}" )
                continue
            }

            # remove files to achieve the _mv effect
            command rm ${_verb-} "$fn"

        done < <( printf '%s\n' "$tar_msg" | sed 's/^a //' )


        # Clean up excluded files and empty dirs in source args
        # - uses sort -r to start depth-first in directories
        while IFS='' read -r dfn
        do
            # Remove files matching patterns from the exclusion list
            # - use globstar in a subshell, since patterns like **/file1 should work
            (
            shopt -s globstar

            while IFS='' read -r pat
            do
                # test globs for filename matches
                # - compgen -G takes globs and outputs filenames, one per line
                while IFS='' read -r fn
                do
                    command rm ${_verb-} "$fn"

                done < <( compgen -G "$dfn/$pat" )

            done < "$xlist"
            )

            # Remove empty dirs
            find "$dfn" -depth -type d -empty -exec \
                bash -c 'command rmdir $2 "$1"' - {} ${_verb-} \;


            # Check for any remaining files
            file_chk=$( command find "$dfn" 2>/dev/null ) && {

                printf '%s\n' "Warning, files remaining:" "$file_chk"
            }
        done < <( sort -r - < <( printf '%s\n' "${d_fns[@]}" ) )

    elif [[ -n $tar_msg ]]
    then
        printf '%s\n' "$tar_msg"
    fi
)
