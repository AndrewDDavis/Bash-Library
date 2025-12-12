# dependencies
import_func seqi \
    || return

# docs
: """Preserve n previous log files

    Usage: rotate_logs <logfile_path> [n]

    This function creates a fresh, empty file at the given path, while
    preserving older files. The previous n log files are preserved by adding
    an integer to the filenames, where n defaults to 7. The file ownership and
    permissions of the log file are preserved during the operation. The older
    log files are compressed using gzip. Empty log files are not rotated.

    This shell function is meant to emulate the behaviour of a savelog command
    of the form:

      savelog -c 7 -ntp /path/to/file.log

    Example:

      rotate_logs /path/to/file.log

    This would move:
      file.log -> file.log.0
      file.log.0 -> file.log.1.gz
      file.log.1.gz -> file.log.2.gz
    ... etc.
"""

rotate_logs() {

    trap 'return' ERR
    trap 'trap - err return' RETURN

    # Parse args
    [[ $# -eq 0  || $1 == @(-h|--help) ]] \
        && { docsh -TD; return; }

    # log file
    local _lfn=$1
    shift

    # n files to keep
    local -i _n=7
    (( $# == 0 )) \
        || { _n=$1; shift; }

    (( _n > 0 )) \
        || err_msg -d 3 "Require _n > 0, got '$_n'"

    _rotate_one() {

        # rotate _lfn with suffix i:
        # _rotate_one i

        trap 'return' ERR
        trap 'trap - err return' RETURN

        local -i i=$1
        local -i j=i+1

        # check log file exists with non-zero size
        if [[ -s ${_lfn}.$i ]]
        then
            /bin/mv -f "${_lfn}.$i" "${_lfn}.$j"
            command gzip -f "${_lfn}.$j"

        elif [[ -e ${_lfn}.$i.gz ]]
        then
            /bin/mv -f "${_lfn}.$i.gz" "${_lfn}.$j.gz"

        else
            return 0
        fi
    }

    if [[ -s $_lfn ]]
    then
        # move prev logs, starting with the oldest
        if (( _n > 1 ))
        then
            local -i k
            for k in $( seqi $((_n-2)) -1 0 )
            do
                _rotate_one $k
            done
        fi

        # move most recent file to .0
        # - cp -p preserves ownership and file mode
        /bin/cp -pf "$_lfn" "${_lfn}.0"
        err_msg -d i "Rotated '$_lfn'"
    fi

    printf '' > "$_lfn"
}
