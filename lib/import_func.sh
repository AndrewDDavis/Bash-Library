# Ensure Bash > v4.0 (from Feb 2009), so mapfile is available
(( ${BASH_VERSINFO[0]-0} > 4 )) \
    || printf >&2 '%s\n' "Error (import_func.sh): Bash v4.0 or higher required"

# function docs for docsh (imported below)
: """Import a function to use in a script or interactive shell

    Usage

        import_func [-f] <function name> ...
        import_func -a [file name] ...

    In its default mode of operation (without -a), this function searches a
    directory tree for function definitions matching the specified name(s). The
    functions are then imported into the current shell session by applying the
    source built-in command to the relevant files.

    By default, the directory containing import_func.sh is searched, which is
    recommended to be ~/.bash_lib/. This may be overridden by setting the BASH_FUNCLIB
    variable or using the -l flag. Symlinks within the library tree are dereferenced and
    followed. Source files are expected to have a .sh or .bash file extension.

    Options

      -a
      : Import all files: import_func will import every file in the library tree
        that has a .sh or .bash extension, except those listed on the command line.

        The file extension may be omitted when listing files. Subdirectories of the
        library may also be excluded by using a '/' at the end of the file name.

      -f
      : Force reimport: normally, import_func will not (re)import a function if a
        function with the same name is already defined. This option forces such
        functions to be reimported by sourcing the relevant file.

      -l
      : Import from local directory. Instead of sourcing files under ~/.bash_lib or
        BASH_FUNCLIB, this searches within the directory tree of the source file of the
        calling function or script, after resolving any symlinks.

        Very useful for larger projects that have their own repository e.g. under
        modules/, with supporting functions spread over multiple files. It also
        keeps the supporting functions out of the main interactive namespace. This
        works as expected across various namespace scopes, e.g. for functions
        previously imported into the interactive namespace, for sourced scripts, and
        for the separate namespaces of executed scripts and subshells.

        Note that import_func will not import the source file of the calling
        function or script, to prevent an endless loop from occurring.

      -v
      : Print verbose messages during the function operation.

    The function normally returns 0 (true), but returns 62 if it cannot find the
    funclib directory, 63 if it cannot find a source file for a function named
    on the command line, or 64 if it finds multiple source files. It also returns
    3, 4 or 5 if there is a problem parsing the command-line arguments, or 9 if
    executables for the find or grep command cannot be located.

    Example 1

      # import dependencies in a script

      [[ \$( builtin type -t import_func ) == function ]] || {
          source ~/.bash_lib/import_func.sh \\
              || return 9
      }

      import_func docsh err_msg \\
          || return

    Example 2

      # import all source files within a directory tree, e.g. for environment setup
      # in .bashrc

      BASH_FUNCLIB=~/.bash_env import_func -a
"""

import_func() {

    # print docs
    [[ $# -eq 0  || $1 == @(-h|--help) ]] \
        && { docsh -TD; return; }

    # Check for functrace (AKA set -T)
    # - it causes the cleanup trap to run on every function return
    [[ $( shopt -o functrace ) == *off ]] \
        || { err_msg 48 "import_func should not be run with functrace enabled"; return; }

    # Set a variable so child import_func calls don't run the cleanup routine
    # - NB, care is taken around later 'source' calls, which shouldn't see the trap.
    #   The return trap is reset before calling source, and restored after the call.
    # - Recall that child function calls don't inherit a return trap, except for
    #   "trap -- '' RETURN" (i.e., a null op). As long as IMPORT_FUNC_LVL is set,
    #   child import_func calls won't call the cleanup routine in their trap.
    if [[ -v IMPORT_FUNC_LVL ]]
    then
        # parent import_func already running

        # manage the LVL variable to improve reporting through _impf_msg
        (( IMPORT_FUNC_LVL++ ))
        trap '
            (( IMPORT_FUNC_LVL-- ))
            trap - err return
        ' RETURN

        # return on non-zero exit code
        trap 'return' ERR

        # retain verbosity of parent call
        [[ -v _impf_verb ]] \
            && local -I _impf_verb \
            || err_msg w "IMPORT_FUNC_LVL=$IMPORT_FUNC_LVL, but _impf_verb not set"

        # functions should also be set, or something fishy is going on
        builtin declare -F _def_libdir >/dev/null \
            || err_msg w "IMPORT_FUNC_LVL=$IMPORT_FUNC_LVL, but _def_libdir not set"

    else
        # no parent import_func running
        local IMPORT_FUNC_LVL=1
        local _impf_verb=1

        # Namespace cleanup routine
        # - unset local functions and reset the return and err traps.
        # - commonly, the files sourced below also contain calls to import_func. The
        #   logic of the IMPORT_FUNC_LVL variable above is meant to ensure that this
        #   cleanup function isn't called when child import_func calls return.
        # - NB, use 'declare -tf _impf_cleanup' if you want to be able to reset the return
        #   trap from inside the cleanup function; otherwise, use 'trap - return' in the
        #   'body' of the trap call.
        # - NB, although care has been taken to save loading time of these functions in
        #   child calls, reading function definitions actually takes very little time in
        #   Bash: <10 us for a resonably short function, or ~ 1 us longer than a no-op.
        #   It somehow seems to take less time than a no-op with a string argument of
        #   the same function definition.
        trap '
            _impf_rtnmsg $?
            unset -f _impf_rtnmsg _impf_msg _impf_arr_match _impf_physpath \
                _impf_parse_args _chk_funcloop _def_libdir _excl_callers \
                _impf_find_cmd _find_env_fns _msfn_grep_cmdln _match_src_fns _imp_fn \
                _match_skel_funcs _skel_grep_cmdln _skel_func _chk_funcdef
            trap - err return
        ' RETURN

        # return on non-zero exit code
        trap 'return' ERR

        _impf_rtnmsg() {

            _impf_msg 2 "return triggered with LVL=$IMPORT_FUNC_LVL"

            if (( _impf_verb > 2 ))
            then
                # very verbose output (debug level)
                _impf_msg 3 "  code $1, ln ${BASH_LINENO[0]} of $( basename "${BASH_SOURCE[1]}" ):"
                _impf_msg 3 "    $( sed -nE "${BASH_LINENO[0]} { s/^[[:blank:]]+//; p; }" < "${BASH_SOURCE[1]}" )"

                local m decs
                mapfile -t decs < <( declare -p FUNCNAME BASH_COMMAND )
                for m in "${decs[@]}"; do _impf_msg 3 "  ${m#declare ?? }"; done
            fi
        }

        _impf_msg() {

            # Print a message if _verb setting is high enough
            # Usage: _impf_msg <level> "message body"
            # - e.g. pass level=0 or 1 to usually print, 2 to print with -v, 3 with -vv, etc.
            # NB:
            # - _impf_verb=1 by default
            # - could also use 'err_msg i ...' here
            # ensure return status is 0
            (( _impf_verb < $1 )) \
                && return
            shift

            local i=2 func=${FUNCNAME[1]-}
            while [[ $func == _* ]]
            do
                # underscore functions are probably not the context we want
                if [[ -n ${FUNCNAME[i]-} ]]
                then
                    func=${FUNCNAME[i]}
                else
                    break
                fi
                (( i++ ))
            done

            # report LVL for import_func calls
            [[ $func == import_func ]] \
                && func+=" (LVL=${IMPORT_FUNC_LVL})"

            printf >&2 "${func}: %s\n" "$@"
        }

        _impf_arr_match() {

            # simple array matching, until array_match can be imported
            # usage: _impf_arr_match <array-name> <string-to-match>
            local yn=1 e
            local -n __arr=$1

            for e in "${__arr[@]}"
            do
                if [[ $e == "$2" ]]
                then
                    yn=0
                    break
                fi
            done

            return $yn
        }

        _impf_physpath() {

            # use python fallback until physpath is imported
            if [[ -n $( command -v physpath ) ]]
            then
                physpath "$1"

            elif [[ -n $( command -v python3 ) ]]
            then
                python3 -c "import os.path; print(os.path.realpath('$1'))"

            else
                printf '%s\n' "$1"
            fi
        }

        _impf_parse_args() {

            local _flag OPTARG OPTIND=1
            while getopts ':ad:flsv' _flag
            do
                case $_flag in
                    ( a ) _all=1 ;;
                    ( d ) libdir=$OPTARG ;;
                    ( f ) _force=1 ;;
                    ( l ) _local=1 ;;
                    ( s ) _skel=1 ;;
                    ( v ) (( _impf_verb++ )) ;;
                    ( : )  err_msg 2 "missing argument for option $OPTARG"; return ;;
                    ( \? ) err_msg 3 "unrecognized option: '-$OPTARG'"; return ;;
                esac
            done
            shift $(( OPTIND-1 ))

            # positional args are function or file names
            if [[ -v _all ]]
            then
                x_fns=( "$@" )

                _impf_msg 3 "x_fns: '${x_fns[*]}'"

            else
                funcs=( "$@" )

                if [[ ! -v _force ]]
                then
                    # filter out known function names to prevent re-importing
                    # - do this early to return as quickly as possible if there's nothing to do
                    # - NB, running this loop for a few funcs takes only ~ 30 us (*micro-seconds*), but
                    #   can save time down the line.
                    local i
                    for i in "${!funcs[@]}"
                    do
                        if builtin declare -F "${funcs[i]}" >/dev/null
                        then
                            _impf_msg 2 "ignoring known function: '${funcs[i]}'"
                            unset 'funcs[i]'
                        fi
                    done
                fi

                _impf_msg 3 "funcs: '${funcs[*]}'"
            fi
        }

        _chk_funcloop() {

            # curtail endless loop of function calls
            # - this can occur if a function is called from one of its dependencies
            # - analagous situation:
            #   foo() { (( i++ )); bar; }
            #   bar() { (( i > 100 )) && { array_match -c FUNCNAME foo; return; }; foo; }
            #   i=0; foo
            # - this simple strategy was adopted rather than, e.g. trying to count the number
            #   of occurrences of import_func in the FUNCNAME stack
            if (( ${#FUNCNAME[@]} > 200 ))
            then
                printf >&2 '%s\n' "Error (import_func): possible function call loop" \
                    "    $( declare -p FUNCNAME )"
                return 81
            fi
        }

        _def_libdir() {

            # define search root for source files
            if [[ -v _local ]]
            then
                # Use dir containing source-file as library path
                if [[ -v 'BASH_SOURCE[2]' ]]
                then
                    local caller_srcfn
                    caller_srcfn=$( _impf_physpath "${BASH_SOURCE[2]}" ) \
                        || { err_msg 9 "physpath error on fn: '${BASH_SOURCE[2]}'"; return; }

                    libdir=$( dirname -- "$caller_srcfn" )

                else
                    # BASH_SOURCE[2] is undefined for import_func call from interactive shell
                    libdir=$( _impf_physpath "${PWD-}" ) \
                        || { err_msg 9 "physpath error on PWD: '${PWD-}'"; return; }
                fi

            elif [[ -n ${libdir-} ]]
            then
                # libdir defined by CLI arguments
                true

            elif [[ -n ${BASH_FUNCLIB-} ]]
            then
                # use env var
                libdir=$BASH_FUNCLIB

            else
                # use the parent dir of this file
                # - e.g. ~/.bash_lib
                libdir=$( dirname -- "$( _impf_physpath "${BASH_SOURCE[0]}" )" )
            fi

            # check libdir
            [[ -d $libdir ]] \
                || { err_msg 62 "libdir not found: '$libdir'"; return; }

            _impf_msg 2 "libdir: '$libdir'"
        }

        _excl_callers() {

            # exclude source files of all calling functions, to prevent circularity
            local fn
            for fn in "${BASH_SOURCE[@]:2}"
            do
                if [[ $fn == main ]]
                then
                    # interactive function
                    continue
                fi

                fn=$( _impf_physpath "$fn" ) \
                    || return

                if _impf_arr_match x_fns "$fn"
                then
                    continue
                else
                    x_fns+=( "$fn" )
                fi
            done

            _impf_msg 2 "x_fns: '${x_fns[*]}'"
        }

        _impf_find_cmd() {

            # define find command to match files in libdir with suffix .sh or .bash

            find_cmd=( "$( builtin type -P find )" -L "$libdir" ) \
                || { err_msg 9 "no executable found for find"; return; }

            # - build file exclusion list using the construct:
            #   find ... \( -name .fdignore -o -name 'a file' \) -prune -o ... -print0
            if (( ${#x_fns[@]} > 0 ))
            then
                find_cmd+=( '(' )

                local i=0 fn np_arg
                for fn in "${x_fns[@]}"
                do
                    # add find args to exclude filename, possibly adding suffixes

                    (( i > 0 )) && find_cmd+=( '-o' )

                    # filename or path
                    np_arg='-name'
                    [[ ${fn%/} == */* ]] \
                        && np_arg='-path'

                    if [[ $fn == */ ]]
                    then
                        # directory
                        find_cmd+=( "$np_arg" "${fn%/}" )

                    elif [[ $fn == *@(.sh|.bash) ]]
                    then
                        # already has extension
                        find_cmd+=( "$np_arg" "$fn" )

                    else
                        find_cmd+=( "$np_arg" "${fn}.sh" -o "$np_arg" "${fn}.bash" )
                    fi

                    (( ++i ))
                done

                find_cmd+=( ')' -prune -o )
            fi

            # - NB, type f matches symlinked files, since we're using -L
            find_cmd+=( -type f \( -name '*.sh' -o -name '*.bash' \) -print0 )

            _impf_msg 3 "find_cmd: '${find_cmd[*]}'"
        }

        _find_env_fns() {

            # define find command to match _env files in libdir

            find_cmd=( "$( builtin type -P find )" -L "$libdir" ) \
                || { err_msg 9 "no executable found for find"; return; }

            # - NB, type f matches symlinked files, since we're using -L
            find_cmd+=( -type f \( -name '*_env.sh' -o -name '*_env.bash' \) -print0 )

            _impf_msg 3 "find_cmd: '${find_cmd[*]}'"
        }

        _match_src_fns() {

            # find source-file names for specified functions using grep

            local grep_cmdln
            _msfn_grep_cmdln \
                || return

            # grep_out will be an indexed array of lines comprising filenames and
            # matched lines, e.g.:
            #   /home/andrew/.bash_lib/shell_scripting/err_msg.sh:err_msg() {
            local grep_out
            mapfile -t grep_out < <( "${grep_cmdln[@]}" )

            (( ${#grep_out[@]} == "${#funcs[@]}" )) \
                || { err_msg 63 "some functions were not found by grep:" \
                                "$( declare -p funcs grep_out )"; return; }

            # regex to match function and file names in lines
            # - similar to the pattern in _skel_grep_cmdln, see notes there
            local bl char rgx
            bl='[[:blank:]]'
            char='[[:alnum:]_@%.+-]'

            rgx="^(.*):${bl}*("
            rgx+="function${bl}+(${char}+)"
            rgx+="|"
            rgx+="(${char}+)${bl}*\(\)"
            rgx+=")(${bl}+[{([]|${bl}*$)"

            # src_fns will be an assoc. array of functions to source files
            local ln fn func
            for ln in "${grep_out[@]}"
            do
                # ensure 1 and only 1 colon in each result
                [[ $ln == *:*  && $ln != *:*:* ]] \
                    || { err_msg 9 "unexpected grep_out line: '$ln'"; return; }

                # use regex to extract the function and file names
                [[ $ln =~ $rgx ]] \
                    || { err_msg 9 "regex did not match line: '$ln'"; return; }

                fn=${BASH_REMATCH[1]}
                func=${BASH_REMATCH[3]}
                [[ -n $func ]] \
                    || func=${BASH_REMATCH[4]}

                # skip _local exclusions
                _impf_arr_match x_fns "$fn" \
                    && continue

                src_fns[$func]=$fn
            done

            _impf_msg 2 "matched source files: '$( declare -p src_fns )'"
        }

        _msfn_grep_cmdln() {

            # grep command line to match specific function definitions in source files

            # define pattern
            # - array to string: (func1|func2|func3)
            local func_alts bl rgx
            bl='[[:blank:]]'
            func_alts=\($( IFS='|'; printf '%s\n' "${funcs[*]}"; )\)
            rgx="^${bl}*("
            rgx+="${func_alts}${bl}*\(\)"
            rgx+="|"
            rgx+="function${bl}+${func_alts}"
            rgx+=")(${bl}+[{([]|${bl}*$)"

            # grep command path and opts
            # - recursive ERE, limit to text-format files, follow symlinks
            # - used to have -l, but need context to make assoc. array
            grep_cmdln=( "$( builtin type -P grep )" -ERI ) \
                || { err_msg 9 "no executable found for grep"; return; }

            grep_cmdln+=( --include='*.sh' --include='*.bash' )
            grep_cmdln+=( -e "$rgx" "$libdir" )
            _impf_msg 3 "grep command-line: '${grep_cmdln[*]}'"
        }

        _imp_fn() {

            # Store and mask any return trap, if set, so it doesn't fire on
            # returning from the source call.
            #
            # NB, this was more necessary before this logic was inside a function.
            # Since I'm not setting the trace attribute of this function, it
            # should not see any return trap. The exception is if the user set -T,
            # but this is checked at the top of the file.

            local _rt
            _rt=$( trap -p return )

            [[ -z ${_rt-} ]] \
                || trap - return

            _impf_msg 2 "sourcing '$1'"

            local -i rc=0
            # shellcheck source=/dev/null
            source "$1" \
                || { rc=$?; printf >&2 '%s\n' "return code $rc received on source of '$1'"; }

            # restore trap
            [[ ${_rt-} != trap\ * ]] \
                || eval "$_rt"

            return $rc
        }

        _imp_env_fn() {

            # check for existence of an env file, and import if found
            if [[ $1 == *.sh  && -e "${1%.sh}_env.sh" ]]
            then
                _imp_fn "${1%.sh}_env.sh"

            elif [[ $1 == *.bash  && -e "${1%.bash}_env.bash" ]]
            then
                _imp_fn "${1%.bash}_env.bash"
            fi
        }

        _match_skel_funcs() {

            # find function names to skeletonize in libdir using grep

            local grep_cmdln
            _skel_grep_cmdln || return

            # grep_out will be an indexed array of lines comprising filenames and
            # matched lines, e.g.:
            #   /home/andrew/.bash_lib/shell_scripting/err_msg.sh:err_msg() {
            local grep_out
            mapfile -t grep_out < <( "${grep_cmdln[@]}" )

            (( ${#grep_out[@]} > 0 )) || {
                err_msg w "no function definitions matched in libdir"
                return 1
            }

            # regex to match function names in lines
            # - similar to the pattern in _skel_grep_cmdln, see notes there
            local bl char rgx
            bl='[[:blank:]]'
            char='[[:alnum:]_@%.+-]'

            rgx="^(.*):${bl}*("
            rgx+="function${bl}+(${char}+)"
            rgx+="|"
            rgx+="(${char}+)${bl}*\(\)"
            rgx+=")(${bl}+[{([]|${bl}*$)"

            # extract func_names from lines
            local ln func
            for ln in "${grep_out[@]}"
            do
                # ensure 1 and only 1 colon in each result
                [[ $ln == *:*  && $ln != *:*:* ]] \
                    || { err_msg 9 "unexpected grep_out line: '$ln'"; return; }

                # use regex to extract the function name
                [[ $ln =~ $rgx ]] \
                    || { err_msg 9 "regex did not match line: '$ln'"; return; }

                func=${BASH_REMATCH[3]}
                [[ -n $func ]] \
                    || func=${BASH_REMATCH[4]}

                func_names+=( "$func" )
            done
        }

        _skel_grep_cmdln() {

            # grep command line to match specific function definitions in source files

            # define pattern to match non-indented functions
            # - Bash functions may be named as "any unquoted shell word that does
            #   not contain '$'", but this definition is slightly more
            #   restrictive. In particular, it excludes punctuation that has
            #   special meaning in the shell.
            # - In addition, names that start with underscore are presumed to be
            #   for internal use, and are excluded from skeletonization.
            # - NB, running this grep cmd in bash_lib/ takes about 10 ms to find
            #   184 function definitions
            #   grep -ERI --include='*.sh' --include='*.bash' "$rgx" bash_lib
            #   + OTOH, running it on a single file takes ~ 5 ms, so it's a big
            #     gain to only run it once.
            #   + And running find to generate the file arguments for grep takes
            #     ~ 15 ms, so not much penalty.
            local bl char c1 rgx
            bl='[[:blank:]]'
            #char='[^][:blank:]|&;()<>{}[$`#!^\/~*?'\''"]'
            #c1=${char%']'}'_]'
            # ^^^ use a positive pattern instead, b/c later eval will be used
            char='[[:alnum:]_@%.+-]'
            c1='[[:alnum:]]'

            rgx="^${bl}*("
            rgx+="function${bl}+${c1}${char}*"
            rgx+="|"
            rgx+="${c1}${char}*${bl}*\(\)"
            rgx+=")(${bl}+[{([]|${bl}*$)"

            # grep command path and opts
            # - recursive ERE, limit to text-format files, follow symlinks
            # - used to have -l, but need context to make assoc. array
            grep_cmdln=( "$( builtin type -P grep )" -ERI ) \
                || { err_msg 9 "no executable found for grep"; return; }

            grep_cmdln+=( --include='*.sh' --include='*.bash' )
            grep_cmdln+=( --exclude='*_env.sh' --exclude='*_env.bash' )
            grep_cmdln+=( -e "$rgx" "$libdir" )
            _impf_msg 3 "grep command-line: '${grep_cmdln[*]}'"
        }

        _skel_func() {

            # define a small placeholder for a function, to save time and memory
            # - unable to avoid use of eval here, so keep it simple; the regex
            #   checks from earlier allow only safe function names.
            # - this takes ~ 15 us

            eval "${1}() { import_func -d \"${libdir}\" -f ${1} && ${1} \"\${@}\"; }"
        }

        _chk_funcdef() {

            # check that function is defined, and not a skeleton function
            # usage: _chk_funcdef <func> <src-file>

            local func_dec
            func_dec=$( declare -f "$1" ) \
                || { err_msg 11 "'${1}' is not defined after sourcing ${2}"; return; }

            [[ $func_dec != "${1} () "$'\n{ \n    import_func'*"${1} && ${1}"* ]] \
                || { err_msg 12 "'${1}' is still skeletonized after sourcing ${2}"; return; }
        }
    fi

    # options and args
    local _all _force _skel _local
    local libdir funcs=() x_fns=()
    _impf_parse_args "$@"
    shift $#

    [[ ! -v _all ]] && (( ${#funcs[*]} == 0 )) \
        && return

    # die if endless loop of function calls detected
    _chk_funcloop

    # define libdir and excluded paths for _all and _local
    _def_libdir
    _excl_callers

    if [[ -v _all && -v _skel ]]
    then
        # skeletonize top-level functions from .sh and .bash files in libdir

        # match and define func_names using grep
        local func func_names=()
        _match_skel_funcs

        for func in "${func_names[@]}"
        do
            _impf_msg 3 "considering for skel: $func"

            if [[ ! -v _force ]] \
                && builtin declare -F "$func" >/dev/null
            then
                # skip func if defined, e.g. imported as a dependency
                continue
            fi

            # define func skeleton
            _skel_func "$func"
        done

        # now import _env files that were excluded above
        local fn find_cmd
        _find_env_fns

        while IFS='' read -rd '' fn <&3
        do
            _imp_fn "$fn" \
                || continue

        done 3< <( "${find_cmd[@]}" )

    elif [[ -v _all ]]
    then
        # Import all .sh and .bash files from libdir (unless excluded)

        local fn find_cmd
        _impf_find_cmd

        # Run find and import the selected files
        # - NB, defining the find command line and running it only takes ~ 10 ms
        while IFS='' read -rd '' fn <&3
        do
            _imp_fn "$fn" \
                || continue

        done 3< <( "${find_cmd[@]}" )  # print0 at end?

    else
        # Find and import specified function(s) from libdir

        # Strategy: the pattern is produced from all the function names, so grep
        # only has to run once. If we get 1 source file for each function name,
        # we will import them all, assuming there's 1 for each. Then at the end,
        # check to make sure all requested functions are defined.

        # match source filenames using grep
        local -A src_fns=()
        _match_src_fns

        local func
        for func in "${!src_fns[@]}"
        do
            if [[ ! -v _force ]] \
                && builtin declare -F "$func" >/dev/null
            then
                # skip func if defined, e.g. imported as a dependency
                continue
            fi

            if [[ -v _skel ]]
            then
                # define func skeleton
                _skel_func "$func"

                # import any associated _env file
                _imp_env_fn "${src_fns[$func]}"

            else
                # import source file and any associated _env file
                _imp_fn "${src_fns[$func]}"
                _imp_env_fn "${src_fns[$func]}"

                # Ensure func was (re-)defined, not e.g. masked by a conditional
                _chk_funcdef "${func}" "${src_fns[$func]}"
            fi
        done
    fi
}


# Import supporting functions when sourcing this file
# - We don't use a _deps array for this, since there can be a namespace collision when
#   the this file is sourced, and _deps is defined in the caller
# - NB, since these functions are used within import_func(), they should not call
#   import_func -l when they are executed. This could set up an endless loop!
#   OTOH, calling import_func in the base of their source files is fine.
#   Of course, these functions are some of the most important ones to the bash_lib
#   system, so their stability is paramount. This call will only fail on very serious
#   problems, such as failing to find libdir or the grep command.
import_func -f physpath err_msg docsh \
    || { printf >&2 'Error: %s\n' "import_func supporting functions not loaded"; return; }

# import these too, but we can fall back on the binaries
import_func basename dirname
