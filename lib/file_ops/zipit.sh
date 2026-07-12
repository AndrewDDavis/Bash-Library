zipit() (

    : """Move files or directory trees to a zip archive.

    This is a wrapper function for quickly adding files to a zip archive,
    and then removing the source files to simulate a move operation.
    It uses reasonable defaults for unix-like operating systems, and takes
    a list of files to exclude from ~/.config/zip/zip_xlist, and a list of
    file types to add without compression from ~/.config/zip/zip_nlist.

    Usage

        zipit [options] [archive[.zip]] path1 [path2 ...]

    If only 1 non-option argument is issued, zipit will create an archive
    in the same directory and named the same way as the input path, with
    a .zip file extension added.

    Optional arguments to zip may be added, as usual (see the man page).

    Expand zip archives using e.g. \`unzip arch1.zip\`. Unzip to stdout with
    '-p' (pipe).

    Examples

    - zip in-place with max compression:

        zipit -9 file.txt

    Zip Command Notes

    - The form of a zip command is
      zip [opts] zipfile file(s)

    - The default options for the zip command are in ZIPOPT, currently:
      '${ZIPOPT-}'

    - Pattern matching by zip is similar to globs, using the special chars
      ?, *, , and [...]. Files beginning with '.' are not treated specially.

    - Patterns provided to -R, -i, and -x are compared against archive paths
      after the filesystem scan. That is, the patterns match paths as if they're
      strings, and * matches across the '/' character just like any other, unless
      the -ws option is used. A pattern such as '*/bar' matches files only, unless
      it ends with a path separator ('/'). Even using '-x */bar/' will fail to
      exclude a directory called bar if files within bar are included in the
      archive. To match (e.g. exclude) a directory and all of its contents, a path
      like '*/bar/*' is necessary (or '**/bar/**' when using -ws). Escape or quote
      wildcard patterns given on the command line to avoid their interpretation by
      the shell.

    Notable options:

     -r : Recurse paths, to include files under any directories provided in the
          arguments. Files included may be tweaked using -x and -i.
     -R : Scan the directory tree starting at the current directory for files
          matching the provided pattern(s). In this case, only patterns are
          provided, rather than file paths to include. It is invalid to specify
          both -r and -R.
     -x : exclude file patterns from archive (literal '@' terminates list).
     -i : include only files matching the pattern.
     -n : do not use compression on listed files.
          per the man page, zip  does not compress files with the following extensions:
          .Z:.zip:.zoo:.arc:.lzh:.arj
          in ~/.config/zip/zip_nlist, the list of files is extended.
     -o : make archive mtime same as newest file in the archive.
    -ws : require ** to match across directory boundaries.
     -y : archive symlinks as symlinks.
    """

    [[ $# -eq 0 || $1 == @(-h|--help) ]] &&
        { docsh -TD; return; }

    # Parse args
    # Count non-option args
    # - last arg must be a source path, unless using zip -@ ...
    n_args=$( printf '%s\0' "$@" | egrep -zc '^[^-]' )

    # Introduce archive name if needed
    # - This is only simple for 1 non-option arg, otherwise you would need to
    #   parse the args as zip does...
    ifn=()
    [[ $n_args -eq 1 ]] && {

        # last arg must be input filename
        ifn1=${@:(-1)}
        ifn+=( "$ifn1" )
        ofn=${ifn%/}.zip

        [[ -e $ofn ]] && {
            err_msg 2 "outfile exists: $ofn"
            return 2
        }

        let "c = $# - 1"
        set -- "${@:1:$c}" "$ofn" "$ifn1"
    }

    [[ -n $(command -v zip) ]] || {
        err_msg 2 "zip command not found"
        return 2
    }

    # Check for option to move (-m? option not implemented yet)
    zip_opts=()
    [[ -n True ]] && zip_opts+=( -m )

    _run_zip() {

        # echo command line and run zip, but not too verbose
        printf ' + zip'

        prev_arg=''
        for arg in "$@"
        do
            if [[ $arg == -x@* ]]
            then
                printf -- " -x@..."

            elif [[ $prev_arg == -n ]]
            then
                printf -- ' ...'

            else
                printf -- " %s" "$arg"
            fi
            prev_arg=$arg
        done
        printf '\n'

        zip "$@"
    }

    # Main run for Info-ZIP

    # many of these may be set in ZIPOPT
    zip_opts+=( -qroy -ws )
    zip_opts+=( -n "$( < $HOME/.config/zip/zip_nlist )" )
    zip_opts+=( "-x@$HOME/.config/zip/zip_xlist" )
    set -- "${zip_opts[@]}" "$@"

    _run_zip "$@"  || {

        ec=$?
        err_msg $ec "zip returned $ec"
        return $ec
    }


    # Clean up excluded files and empty dirs in source dirs
    # - only if --move was used
    _moving() {
        printf '%s\0' "$@" | command egrep -qz '^-m$'
    }
    file_chk=""

    { [[ ${#ifn[@]} -gt 0 ]] && _moving "$@"; } && {

        for dfn in "${ifn[@]}"
        do
            [[ -d $dfn ]] && {

                # remove files matching patterns from the exclusion list
                # - use globstar in a subshell, given that **/file1 should work
                (
                shopt -s globstar

                while IFS='' read -r pat
                do
                    # test globs for filename matches
                    # - compgen outputs filenames, one per line
                    while IFS='' read -r fn
                    do
                        # - with a bit of output formatting
                        command rm -v "$fn" > \
                            >( sed -E '/^removed / s/^/ + /' )

                    done < <(compgen -G "$dfn/$pat")

                done < "$HOME/.config/zip/zip_xlist"
                )

                # also remove empty dirs
                # - with a bit of output formatting
                find "$dfn" -depth -type d -empty -exec     \
                    bash -c 'command rmdir -v $1' - {} \; > \
                    >( sed -E 's/^rmdir: removing directory,/ + removed dir/' )
            }

            # warn on remaining files
            file_chk="${file_chk}$(find "$dfn" 2>/dev/null)"
        done
    }

    [[ -n $file_chk ]] && {

        echo "Warning, files remaining:"
        printf '%s\n' "$file_chk"
    }

    return 0
)
