sed-delln() {

    [[ $# -eq 0  || $1 == @(-h|--help) ]] && {

        : """Delete lines matching regex pattern.

        Usage: sed-delln [options] <pattern> <filename>

        Options

          -f : after filtering and showing the diff, remove the backup file.

        Notes

        - Pattern is an extended regular expression interpreted by sed.
        - A backup is made, and the diff will be shown at the end.
        - All unrecognized arguments are passed to sed.

        Example: sed-delln '^dirname' bash_extended_history
        """
        docsh -TD
        return
    }

    # defaults and args
    local _rmf

    local OPT OPTIND=1
    while getopts ":f" OPT
    do
        case $OPT in
            ( f ) _rmf=1 ;;
            ( \? ) break ;;
        esac
    done
    shift $(( OPTIND - 1 ))

    # pattern and filename
    local _fn="${@:(-1)}"
    local _pat="${@:(-2):1}"
    set -- "${@:1:$#-2}"

    # find backup extension, adding integer as necessary
    _bfn=${_fn}.bak
    local i=1
    while [[ -e ${_bfn} ]]
    do
        let 'i += 1'
        _bfn=${_fn}.bak${i}

        (( i == 100 )) && {
            err_msg 2 "found 99 backup files for $fn, aborting."
            exit 2
        }
    done

    local _bext=${_bfn##*.}

    # run sed
    sed -E --in-place=".$_bext" "$@" "/$_pat/ d" "$_fn"

    # show diff
    #git diff --minimal --word-diff=color --no-index
    diff -us --color=always "$_bfn" "$_fn" | less -FR

    # clean up
    if [[ ${_rmf:-} ]]
    then
        command rm "$_bfn"
    fi
}
