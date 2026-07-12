# TODO:
#
# - make a --no-hist option to exclude shell history files, like:
#   -g '!*_history*'
#
# - testing matrix in ~/Scratch/grepfiles:
#
#   'ugrep-files -tTi attachment' from '~/Documents/Health...' dir
#   'ugrep-files -i truecrypt' from '~/Documents/Computing...' dir


# dependencies
import_func run_vrb \
    || return

# aliases are also defined in the associated _env file

# docs
: """Search for files by their content

    Usage: grep-files [opts] <pattern> [path-root ...]

    Grep-files recursively searches a directory tree for text files with content matching
    the pattern. By default, symlinks in the tree are followed, and the pattern is
    interpreted as a POSIX extended regular expression (ERE regex, as in 'grep -E'). If no
    path-roots are given, the working directory is searched.

    By default, this function calls \`ugrep\` with the options '-RljIUY' and '--sort',
    described below. Since \`ugrep\` includes most of the existing and planned functionality
    of the old \`grep-files\` function that called GNU \`grep\`, this function is mostly a
    wrapper for \`ugrep\`. It passes all arguments through, except those listed below. The
    defaults can be negated by using the long option form '--no-<option>', e.g.
    '--no-ignore-case'.

      --matches
      : this option negates -l, and is easier to type than '--no-files-with-matches'. It
        also enables '--heading' and '-n', to give output similar to '--pretty'.

      --to-array=<array-name>
      : place the matching file-names in the indicated array, instead of printing.

      --verb[ose]
      : print the ugrep command as it is run

    Multiple patterns may be supplied to any grep tools, including \`ugrep\`, using a
    command line syntax like \`-e 'A' -e 'B'\`. These are interpreted with a logical
    OR condition, as if the expression had been \`'A|B'\`. When searching for files
    that match multiple patterns on the same line (logical AND), one can use a
    pattern like 'A.*B|B.*A'. When the matches may be on different lines,
    traditional greps and ripgrep require multiple calls in a pipeline. The \`git
    grep\` tool introduced the options '--and' and '--not' to facilitate this, and
    those are also supported by \`ugrep\`. However, \`ugrep\` also supports a
    simpler boolean logic syntax using '-%' and '-%%', as described below.

    Output formatting options in \`ugrep\` are numerous, including '--format',
    '--pager', options for CSV, JSON, or XML, and the catch-all
    '--pretty', which invokes '--color', '--heading', '-n', '--sort', '--tree' and
    '-T'. Other features beyond traditional grep include config files, launching an
    interactive query interface with '-Q', matching file types with '-t', '-M', and
    '-O', searching compressed files with '-z', other file types with '--filter',
    replacement of match text with '--replace', fuzzy matching with '-Z', etc. The
    documentation for \`ugrep\` is also excellent, both at ugrep.com, and inline
    using e.g. \`ugrep --help regex\`.

    Option '--index' causes ugrep to use any index files encountered in the
    directory tree. The index files are created by \`ugrep-indexer\`, one per
    indexed directory, and are named '._UG#_Store'. This generally speeds up
    recursive searches, especially for compressed files. Ugrep's indexed-based
    search is safe in that it never skips new or updated files that may now match.
    Refer to the 'ugrep-indexer' manpage and my notes in 'File Search' for details.

    Notable \`ugrep\` options (grep-files defaults '-RljIUY' and '--sort')

      -r (--recursive), -R (--dereference-recursive), -S (--dereference-files)
      : Search recursively within files and directories. '-R' will follow all
        symlinks within the search tree. '-S' will follow symlinks to files, but
        not directories.

      -l (--files-with-matches)
      : Print only the list of filenames, without printing matched lines.

      -c (--count)
      : Print the count of matching lines for each filename, rather than the
        text of the lines. Print the count of total matches with '-o'. Omit files
        with zero matches using '-m 1,'.

      -i (--ignore-case), -j (--smart-case)
      : Case insensitive search. '-j' is case-insensitive unless the pattern has
        an upper-case ASCII letter.

      -w (--word-regexp)
      : Match the pattern as a word, surrounded by non-word characters. Words are
        formed from letters, digits, and underscores.

      -x (--line-regexp)
      : Match whole lines only (i.e. pattern is surrounded by '^' and '$').

      -I (--ignore-binary)
      : Ignore binary files. Once grep determines that a file contains binary rather
        than text data (e.g. when a NUL byte is encountered), the rest of the file
        is skipped as if it contains no matches. By default, grep reports matches in
        binary files with a message to STDERR, but suppresses output.

      -. (--hidden)
      : Match hidden files, which are otherwise ignored by default.

      -U (--ascii)
      : Disable Unicode matching. The pattern matches bytes, as in GNU grep, rather
        than Unicode characters.

      -Y (--empty)
      : Allow empty-matching patterns like 'x*' to pass through unchanged and match
        all lines (or files) as other grep variants would. By default, ugrep would
        change such a pattern to 'x+', in an effort to guess what you meant.

      -% (--bool), -%% (--bool --files)
      : Boolean matching of lines or whole files. The AND operator is represented by
        space, OR by '|', and NOT by '-', and grouping occurs with '(...)'. E.g.
        'A -B' is the same as 'A AND NOT B'. The options '--and', '--andnot', and
        '--not' are also available, so that the above could be written '-e A
        --andnot B'.

      -g GLOB, --(ex|in)clude[-dir]=GLOB
      : Use glob patterns search only certain files, or exclude some files from the
        search. The '--exclude' form is the same as \"-g '!GLOB'\". Globs usually
        only match files, but globs ending in '/' match only directories as in the
        --include-dir form. Globs usally match only the basename, but they match
        the whole path if they contain '/' somewhere other than the end.

        All globs use the gitignore syntax, which has slight differences compared
        to Bash. Refer to \`ugrep --help globs\`.

        The similar '--(ex|in)clude-from=FILE' options specify a file of globs to
        to specify the searched files. The '--ignore-files[=...]' option causes
        \`ugrep\` to respect ignore rules found in a standardized filename in the
        search tree, by default '.gitignore'.

      --sort
      : Sort output, rather than presenting matches as they are found. Without an
        argument, sorts by name, but can also sort by times, size, or best during
        fuzzy matches.

      -^ (--tree)
      : Display file matches as tree when using -c, -l, or -L.

      --index
      : Speed up recursive searches by using index files created by 'ugrep-indexer'
"""

ugrep-files() {

    [[ $# -eq 0  || $1 == @(-h|--help) ]] \
        && { docsh -TD; return; }

    # err trap and clean up
    trap 'return' ERR
    trap 'return 130' SIGINT
    trap '
        local c=$?

        unset -f _def_cmd _parse_opts _match_fns
        trap - err int return

        # reissue SIGINT if an interrupt triggered the return
        (( c == 130 )) \
            && kill -s SIGINT "$$"
    ' RETURN

    _def_cmd() {

        ug_cmd=( "$( builtin type -P ugrep )" ) \
            || { err_msg 9 "ugrep not found on PATH"; return; }

        # - NB, some of the code in _parse_opts relies on the order here
        ug_cmd+=( '-RljIUY' '--sort' )
    }

    _parse_opts() {

        # deal with ugf options; pass all else to ugrep
        while [[ -v 1 ]]
        do
            case $1 in
                ( '--' )
                    # end of options
                    ugf_args+=( "$@" )
                    return
                ;;
                ( --matches )
                    # work around bug "invalid option --no-files-with-matches"
                    # - otherwise, we could do: ug_cmd+=( --no-files-with-matches --pretty )
                    ug_cmd[1]=${ug_cmd[1]/l/}
                    ugf_args+=( --heading -n )
                ;;
                ( --to-array* )
                    if [[ $1 == --to-array=* ]]
                    then
                        to_array=${1#--to-array=}
                    else
                        to_array=${2} || return
                        shift
                    fi
                    ug_cmd+=( --null )
                ;;
                ( --verb | --verbose )
                    (( _verb++ ))
                ;;
                ( * )
                    # options or args meant for ugrep
                    ugf_args+=( "$1" )

                    if [[ $1 == -*i*  && $1 != -*-* ]]
                    then
                        # work around behaviour of -j overriding -i
                        # - could also use --no-smart-case now
                        ug_cmd[1]=${ug_cmd[1]/j/}
                    fi
                ;;
            esac
            shift
        done
    }

    _match_fns() {

        # match using grep
        if [[ ! -v to_array ]]
        then
            # - for quoted output to shell, use -m1 --format='%h%~'. In a script like this,
            #   it is better to simply use -l.
            run_vrb "${ug_cmd[@]}" "${ugf_args[@]}"

        else
            # capture filenames in array
            # - for notesh, start index at 1 to match the selection display
            local O_arg
            if [[ ${FUNCNAME[2]-} == notesh ]]
            then
                O_arg='-O1'
            fi

            mapfile -d '' ${O_arg-} "$to_array" < \
                <( run_vrb "${ug_cmd[@]}" "${ugf_args[@]}" )

            # check ugrep return status from subprocess
            local grep_rs
            wait $!  || {
                grep_rs=$?
                (( grep_rs == 1 )) && return 1
                err_msg $grep_rs "grep command call error $grep_rs"
                return
            }
        fi

        # tested grep + find for matching
        # - about the same time, but more complicated
        # - might be faster for larger number of files
        #   printf 'find + grep vvv\n\n'
        #   time find ~/Sync/Notes/ \( -type d -name .git -prune \) -o -type f -name '*.md.txt' \
        #       -exec egrep -li "^#.*$@" {} +
        # - NB, sed is unwieldy for this task
    }

    # NB, notesh calls ugrep-files, but also includes significant code to parse ugrep
    # options, so look there if you need some code for that.

    # defaults and args
    local ug_cmd
    _def_cmd

    local _verb=1 ugf_args to_array
    _parse_opts "$@"
    shift $#

    _match_fns
}
