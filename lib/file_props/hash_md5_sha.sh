md5sum-mk() {

    if [[ $# -eq 0 || $1 == @(-h|--help) ]]
    then
        docsh -TD """Create md5 checksum file(s)

        Usage: md5sum-mk <filename> ...

        For each passed file, creates file at same path, with '.md5' added to the name.

        To check a file, run:

          md5sum -c file.md5
        """
        return 0
    fi

    # return on error
    trap 'trap-err $?; return' ERR
    trap 'trap - ERR RETURN' RETURN

    local fn

    for fn in "$@"
    do
        if [[ -e ${fn}.md5 ]]
        then
            echo >&2 "file exists: '${fn}.md5'; skipping."
            continue
        fi

        md5sum "$fn" > "${fn}.md5"
    done
}
