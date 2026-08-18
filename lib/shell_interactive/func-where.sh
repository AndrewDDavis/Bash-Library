# docs
: """Print file path of a function definition

    Usage: func-where [options] <func-name> ...

    This function prints the file path and line number for the definition of a
    function. It temporarily enables the extdebug option, then runs 'declare -F'
    to get the information.

    Options

      -e
      : open function source file in EDITOR instead of printing the path.

      -s
      : re-import the function by sourcing the relevant file instead of printing
        the path.
"""

func-where() {

    # defaults and options
    local _s _e

    local flag OPTARG OPTIND=1
    while getopts ':esh' flag
    do
        case $flag in
            ( e ) _e=1 ;;
            ( s ) _s=1 ;;
            ( h ) docsh -TD; return ;;
            ( \? ) err_msg 3 "unknown option: '-$OPTARG'"; return ;;
            ( : )  err_msg 4 "missing argument for -$OPTARG"; return ;;
        esac
    done
    shift $(( OPTIND-1 ))

    # clean-up trap
    trap '
        unset -f _get_func_info _func_not_found _check_skel _vrb_run _check_srcln
        trap - return
    ' RETURN

    _get_func_info() {

        # gather func source fn and line

        # define regex separately to avoid shell quoting issues
        # - pattern matches function name, line number, and source file path
        # - e.g. for the_func() defined in 'a func.sh', declare -F would output:
        #   'the_func 1 a func.sh'
        # - then, [[ $sss =~ ^([^ ]+)\ ([0-9]+)\ (.+)$ ]] would produce:
        #   BASH_REMATCH=([0]="the_func 1 a func.sh" [1]="the_func" [2]="1" [3]="a func.sh")
        local regex_ptn='^([^ ]+) ([0-9]+) (.+)$'

        local dec_out
        dec_out=$( shopt -s extdebug; declare -F "$func_nm" ) \
            || { _func_not_found; continue; }

        [[ $dec_out =~ $regex_ptn ]] \
            || { err_msg 6 "dec_out did not match regex"; return; }

        src_fn=${BASH_REMATCH[3]}
        src_ln=${BASH_REMATCH[2]}
    }

    _func_not_found() {

        # not a function; check for alias
        local al_out
        if al_out=$( alias "$func_nm" 2>/dev/null )
        then
            err_msg 5 "not a function, but found alias: ${al_out#*=}"
        else
            err_msg 6 "function not found: '$func_nm'"
        fi
    }

    _check_skel() {

        if [[ $src_fn == *import_func.sh  && $func_nm != import_func ]]
        then
            # func defn is a skel_func (placeholder function definition)
            local skel_defn regex_ptn libdir
            skel_defn=$( builtin declare -pf "$func_nm" )

            regex_ptn='import_func -d "(.*)" -f'

            [[ $skel_defn =~ $regex_ptn ]] \
                || { err_msg 7 "skel_defn did not match regex"; return; }

            libdir=${BASH_REMATCH[1]}

            # evaluate import_func with the lib_dir from the skel func
            import_func -d "$libdir" -f "$func_nm"

            _get_func_info
        fi
    }

    _vrb_run() {
        local cmd=( "$@" )
        printf >&2 '%s\n' "${PS4}${cmd[*]}"
        "${cmd[@]}"
    }

    _check_srcln() {

        # check source line
        # - NB, if there a sub-functions defined within the function, declare -F may
        #   return the line-no for one of those! Yikes, better check.
        # - per bash manpage:
        #   fname () compound-command [redirection]
        #   function fname [()] compound-command [redirection]
        # - a compound command is surrounded by {...}, (...), [[...]], or ((...))
        # - bash-completion package uses:
        #   _comp_abspath()
        #   {
        #   ...
        local funcdef_ptn="^[[:blank:]]*("
        funcdef_ptn+="${func_nm}[[:blank:]]*\\(\\)"
        funcdef_ptn+="|function[[:blank:]]+${func_nm}([[:blank:]]*\\(\\))?"
        funcdef_ptn+=")([[:blank:]]*[{([]|\$)"

        # - read source file lines into array
        local -a src_lines
        mapfile -t -O1 src_lines < "$src_fn"

        if [[ -z ${src_lines[src_ln]-} ]] \
            || [[ ! ${src_lines[src_ln]} =~ $funcdef_ptn ]]
        then
            # search for the correct line
            local i m
            for (( i=1; i<=${#src_lines[*]}; i++ ))
            do
                [[ ${src_lines[i]} =~ $funcdef_ptn ]] && {
                    src_ln=$i
                    m=1
                    break
                }
            done

            [[ -v m ]] \
                || { err_msg 9 "func defn for '$func_nm' not found at line $src_ln of '$src_fn': ${src_lines[src_ln]}"; return; }
        fi
    }

    local func_nm src_fn src_ln
    for func_nm in "$@"
    do
        # gather func defn info, and make sure it's not a placeholder
        _get_func_info \
            || continue
        _check_skel \
            || continue

        if [[ -v _s ]]
        then
            # source the function definition file
            _vrb_run builtin source "$src_fn"

        elif [[ -v _e ]]
        then
            # open source file in editor
            _vrb_run "$EDITOR" "$src_fn"

        else
            # print source filename and line

            _check_srcln \
                || continue

            # grep-style context
            [[ $# -gt 1 ]] &&
                printf '%s' "${func_nm}: "

            printf '%s\n' "ln. $src_ln in '$src_fn'"
        fi
    done
}
