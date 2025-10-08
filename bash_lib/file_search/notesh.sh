# dependencies
import_func run_vrb vrb_msg std-args array_match array_irepl \
    str_split str_wrap is_int ugrep-files \
    || return

: """Open notes matching a pattern

    Usage: notesh [options] [--] [grep-options] [pattern] [search-root]

    Search for and open a notes file with content that matches a pattern. If more than
    one file is matched by the pattern, an interactive selection screen is presented.

    The pattern matching is done by \`ugrep\`, via the \`ugrep-files\` function. This
    uses smart-case matching and POSIX ERE syntax by default. The pattern may be
    provided using options, e.g. -e or -%%, or as the first positional argument.

    Unless a search-root argument is provided on the command-line, text files in
    '~/Documents' are searched, and any symlinks encountered are dereferenced and
    followed. If the working directory is a subdirectory of '~/Documents', the working
    directory is used as the search root instead. Per ugrep defaults, hidden files and
    directories are never searched, unless the -. (or --hidden) option is used.

    In the case of 'simple' calls to notesh, the pattern is modified to match only
    section headings (markdown and asciidoc supported). In this case, a glob is also
    used to only match files with plausible extensions. This occurs when the pattern
    comprises simple words, without regex pattern characters other than '.'. Also, a
    notesh call is considered simple only when the following pattern-related options are
    not used: -e, --regexp, -f, --file, -N, --neg-regexp, -%, --bool, -%%, --files,
    --and, --andnot, --not.

    Options

      -a
      : match anywhere in the file, don't add section heading regex to simple patterns

      -h
      : add the regex logic to match a header, even if the pattern is not considered
        simple. This only works when the pattern is provided as a positional arg.

      -o <p|e|s|v>
      : open file using PAGER (default), EDITOR, sublime text ('subl -n'), or vs-code
        ('code -n'). Only the first character of the argument is used, so that 'subl' or
        'VSCode' would also work as expected.

      -x 'cmd ...'
      : open file using custom command; the argument will be split into words.
"""

notesh() {

    [[ $# -eq 0 || $1 == @(-h|--help) ]] \
        && { docsh -TD; return; }

    # err trap and cleanup routine
    trap 'return' ERR
    trap '
        local c=$?

        unset -f _parse_opts _parse_ugopts _chk_simpcl _chk_srchroot _select_fns
        trap - err int return

        # reissue SIGINT if an interrupt triggered the return
        (( c == 130 )) \
            && kill -s SIGINT "$$"
    ' RETURN

    _parse_opts() {

        # root of search tree
        doc_root=$HOME/Documents
        [[ $PWD == ${doc_root}/* ]] \
            && doc_root=.

        # default opener is PAGER
        str_to_words opener "${PAGER:-less}"

        # args
        local flag OPTIND=1 OPTARG
        while getopts ':aho:x:' flag
        do
            case $flag in
                ( a )
                    full_match=1
                ;;
                ( h )
                    hd_match=1
                ;;
                ( o )
                    # define opener from first char of OPTARG
                    local oc=${OPTARG:0:1}
                    case ${oc,,} in
                        ( p ) str_to_words -q opener "${PAGER:-less}" ;;
                        ( e ) str_to_words -q opener "${EDITOR:-vi}" ;;
                        ( s ) opener=( "$( builtin type -P subl )" -n ) ;;
                        ( v ) opener=( "$( builtin type -P code )" -n ) ;;
                    esac
                ;;
                ( x )
                    str_to_words -q opener "$OPTARG"
                ;;
                ( \? )
                    # likely [u]grep option: preserve it and stop processing options
                    # - OPTIND will have advanced if a lone option was used (like -X) rather than a blob
                    flag=$(( OPTIND-1 ))
                    [[ ${!flag} == -${OPTARG} ]] &&
                        (( OPTIND-- ))
                    break
                ;;
                ( : )
                    err_msg 2 "missing argument for '$OPTARG'"
                    return
                ;;
            esac
        done
        n=$(( OPTIND-1 ))
    }

    _parse_ugopts() {

        # Keep command-line argument blobs intact while identifying pattern arg(s)
        # Usage: _parse_ugopts A1 A2 A3 \"\$@\"

        # - call std-args with the list of ugrep flags that need args
        # - this clears and sets _optargs, _posargs, and _stdopts
        local sf lf
        sf='efdgmtABCDJKMNO'
        lf='regexp file from neg-regexp and not andnot
            after-context before-context context
            colors colours delay depth encoding
            filter filter-magic-label format file-extension file-type
            glob iglob context-separator jobs label file-magic
            min-line max-line range min-count max-count max-files
            binary-files devices directories replace zmax
            exclude exclude-dir exclude-from exclude-fs
            include include-dir include-from include-fs'

        std-args _optargs _posargs "$sf" "$lf" -- "$@" \
            || return

        local i
        while i=$( array_match -n _stdopts '--(and|not|andnot)=-e' )
        do
            # deal with --and [-e] PAT
            # - NB, the manpage says --not and --andnot can be used like --not -e PAT,
            #   but this gives an error; really you can only do --andnot(=| )PAT
            local bflag=${_stdopts[i]%'=-e'}

            # find the offending entries in _optargs
            local o f=0
            for o in "${!_optargs[@]}"
            do
                if [[ ${_optargs[o]} == "$bflag"  && ${_optargs[o+1]} == '-e' ]]
                then
                    f=1
                    break
                fi
            done

            # check found and posarg
            { (( f )) && [[ -v _posargs[o+2] ]]; } \
                || break

            # fix _stdopts, as --and -ePAT
            array_irepl _stdopts i "$bflag" "-e${_posargs[o+2]}"

            # move the pattern from _posargs to _optargs
            _optargs[o+2]=${_posargs[o+2]}
            unset '_posargs[o+2]'
        done
    }

    _chk_simpcl() {

        # check for pattern-related ugrep options
        local pat_flags='-(e|f|N|-(regexp|file|neg-regexp)=).+'
        pat_flags+='|-(%|%%|-bool|-files)'
        pat_flags+='|--(and|not|andnot)(=.*)?'

        if ! array_match _stdopts "$pat_flags"
        then
            # no pattern yet: get it from 1st postnl arg
            (( ${#_posargs[*]} > 0 )) \
                || { err_msg 3 'no pattern found'; return; }

            # - set pat_i to first _posargs index
            local pos_is=( "${!_posargs[@]}" )
            pat_i=${pos_is[0]}

            if [[ ${_posargs[pat_i]} == '--' ]]
            then
                # '--' is not a real arg
                if [[ -v 'pos_is[1]' ]]
                then
                    pat_i=${pos_is[1]}
                else
                    err_msg 3 'no pattern found'
                    return
                fi
            fi

            # regex to match a 'simple' pattern
            # - starts with alpha-num char, later can be blanks, ., and -
            local simpl_rgx
            simpl_rgx='^[[:alnum:]]'
            simpl_rgx+='[[:alnum:][:blank:].-]*$'

            if  [[ -v hd_match ]] \
                || [[ ! -v full_match
                && ${_posargs[pat_i]} =~ $simpl_rgx ]]
            then
                # simple pattern: add regex for heading lines (markdown or adoc)
                # - refer to the  _expand_keyword() function in scw()
                # - this specific form works around an odd bug with '^[#=]...', which
                #   works for a search on fried or beans, but no refried!
                _posargs[pat_i]="(^#|^=).*${_posargs[pat_i]}"

                # match only files with a plausible extension
                # - NB, matching no extension at the same time is tricky: it's possible with
                #   the glob -g '!*.*', but that will exclude all the files with extensions
                #   (--exclude patterns take priority over --include patterns).
                # - you could use e.g. fd, with the '^[^.]+$' regex to create the file list
                # - or do a seperate search with the no-extension glob...
                _optargs+=( -O 'md,adoc,txt,text,markdown' )
            fi
        fi
    }

    _chk_srchroot() {

        # check whether search dir(s) provided with positional args
        local n=${#_posargs[*]}

        if (( n > 0 ))
        then
            # identify pos-arg array indices
            local pos_is=( "${!_posargs[@]}" )
            local i=0

            if [[ ${_posargs[${pos_is[i]}]} == '--' ]]
            then
                # '--' is not a real arg
                (( ++i ))
                (( --n ))
            fi

            if [[ -v pat_i ]]
            then
                # pattern uses a pos-arg
                (( ++i ))
                (( --n ))
            fi
        fi

        if (( n > 0 ))
        then
            # the remaining pos-args would be file paths
            # - NB, [[ -v pos_is[i] ]] must be true when n > 0
            local fn
            for fn in "${_posargs[@]:${pos_is[i]}}"
            do
                [[ $fn == */  && $fn != '/' ]] \
                    && fn=${fn%/}

                srch_roots+=( "$fn" )
            done
        else
            # default search root
            srch_roots=( "$doc_root" )
            _posargs+=( "$doc_root" )
        fi
    }

    _select_fns() {

        # select a file from the matches

        # selection is easy when there's only 1
        if (( ${#matched_fns[@]} == 1 ))
        then
            sel_fns[0]=${matched_fns[1]}
            vrb_msg 1 "Matched ${sel_fns[0]}"
            return
        fi

        # improve file path strings for display
        # - replace HOME with ~ in root dir path(s)
        # - strip root dir from filenames (if only 1 root)
        # - wrap file paths at a comfortable width, and indent following lines
        # - bold file basenames and root dir
        local _bld _rsb _rst
        _bld=$'\e[1m'
        _rsb=$'\e[22m'
        _rst=$'\e[0m'

        # print context line when there's only 1 search root dir
        local dr fn fn_bn fns_dsp=()
        if (( ${#srch_roots[*]} == 1 ))
        then
            dr=${srch_roots[0]}
            printf >&2 '%s\n' '' \
                "Matching files from '${_bld}${dr/#"$HOME"/\~}/${_rsb}':" ''

            for fn in "${matched_fns[@]}"
            do
                fn=$( str_wrap -w88 -i'    ' "${fn#"${dr}"/}" )
                # fn=$( command fmt -sw88 <<< "${fn#"${dr}"/}" )
                # fn="${fn//$'\n'/&    }"
                fn_bn=${fn##*/}
                fn=${fn%"$fn_bn"}${_bld}${fn_bn}${_rsb}

                fns_dsp+=( "$fn" )
            done

        else
            # with multiple search root dirs, just replace HOME with ~ and bold the basenames
            printf >&2 '%s\n' ''

            for fn in "${matched_fns[@]}"
            do
                fn=$( str_wrap -w88 -i'    ' "${fn/#"$HOME"/\~}" )
                # fn=$( command fmt -sw88 <<< "${fn/#"$HOME"/\~}" )
                # fn="${fn//$'\n'/&    }"
                fn_bn=${fn##*/}
                fn=${fn%"$fn_bn"}${_bld}${fn_bn}${_rsb}

                fns_dsp+=( "$fn" )
            done
        fi

        # Call the Bash builtin 'select'
        # - sel is set to the displayed filename, or null when response to select is
        #   invalid (not a listed number)
        # - the REPLY variable has the actual response from the user
        # - Ctrl-D prevents a selection and returns 1, hence '|| return' below
        # - Ctrl-C (interrupt) skips the || clause, but triggers the trap on INT in the
        #   parent function, since SIGINT traps are inherited
        local PS3 sel nums
        PS3=$'\n''File number(s) to open (e.g. 2, or 1,3,5; can also use a = all or ^D = cancel)'$'\n  : '

        select sel in "${fns_dsp[@]}"
        do
            sel_fns=()
            if [[ -n $sel ]]
            then
                # single number provided
                # recover the un-decorated filename from the selection
                sel_fns=( "${matched_fns[REPLY]}" )

            else
                # response was not a single number
                if [[ $REPLY == a ]]
                then
                    # select all
                    sel_fns=( "${matched_fns[@]}" )

                else
                    # handle list, e.g. 2,3,4
                    str_split -qd ',' nums "$REPLY"
                    is_int "${nums[@]}" \
                        || { vrb_msg 1 "invalid reply: '$REPLY'" "expected e.g. '1' or '2,4'"; continue; }

                    local n m=${#matched_fns[*]}
                    for n in "${nums[@]}"
                    do
                        (( n > 0 )) && (( n <= m )) \
                            || { vrb_msg 1 "invalid value: '$n'"; continue 2; }

                        sel_fns+=( "${matched_fns[n]}" )
                    done
                fi
            fi
            [[ -v sel_fns[*] ]] && break

        done || return

        # TODO:
        #
        # - consider using fzf, e.g.
        #   sel_fns[0]=$( fzf <<< $( printf '%s\n' "${matched_fns[@]}" ) )
        #   -m for multi
        # - or one of the TUI menu programs, like 'dialog'
    }


    # set defaults and parse options
    local doc_root opener full_match hd_match _verb=2
    local -i n
    _parse_opts "$@"
    shift $n

    # sort args into a standard form for ugrep
    local _stdopts _optargs _posargs
    _parse_ugopts "$@"
    shift $#

    # modify simple command-lines to match headings
    local pat_i
    _chk_simpcl

    # ensure search root
    local srch_roots=()
    _chk_srchroot

    # # [u]grep command path and default args
    # local grep_args=()
    # _def_grep_args "$@"

    # match files and select one to open
    local matched_fns=() sel_fns=()
    ugrep-files --to-array=matched_fns "${_optargs[@]}" "${_posargs[@]}"

    # return and run cleanup in case the user hits CTRL-c at selection
    # - ugrep-files clears the INT trap, so this needs to go below
    trap 'return 130' SIGINT

    _select_fns

    run_vrb "${opener[@]}" "${sel_fns[@]}"
}



# TODO:
# - syntax highlighting:
#   from [xdg-ninja](https://github.com/b3nj5m1n/xdg-ninja)
#     + glow for rendering Markdown in the terminal (bat, pygmentize or highlight can be used as fallback, but glow's output is clearer and therefore glow is recommended)
#     + use [glow](https://github.com/charmbracelet/glow) to render markdown in the terminal using a pager
#
# - create project aliases, like --bread, or --project=bread
#
# - if a headings search matches nothing, automatically try full text
#
# - allow GNU grep as well
