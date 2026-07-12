archive-check() {
    # alias for tar-check
    tar-check "$@"
}

: """Check tarfiles using compression tools and tar

    Usage: tar-check <file-path> ...

    For compressed archives, this function relies on the the gzip, bzip2, xz, and
    zstd programs to test the archive's integrity. The program is chosen based on
    the file extension.

    For tar-files, compressed or not, the tar command is also used to test the
    metadata integrity of the archive.

    From the \`tar\` manual:

      > A tar-format archive contains a checksum that most likely will detect
        errors in the metadata, but it will not detect errors in the data.
"""

tar-check() {

    [[ $# -eq 0  || $1 == @(-h|--help) ]] &&
        { docsh -TD; return; }

    trap '
        unset -f _test_archive
    ' RETURN

    local ifn ext

    _test_archive() {
        # use cmd ($1) to test infile ($ifn)
        # - optional message on $2
        # - afterward, report OK or provide a newline before an error message

        printf >&2 '%s' "$ifn: checking ${1}${2:+ ($2)} checksum ... "

        {
            if [[ $1 == tar ]]
            then
                command "$1" -tf "$ifn" > /dev/null
            else
                command "$1" -t "$ifn"
            fi
        } \
            && printf >&2 '%s\n' "OK" \
            || printf >&2 '\n'
    }

    for ifn in "$@"
    do
        ext=${ifn##*.}

        case $ext in
            ( gz | tgz | taz )
                _test_archive gzip CRC-32
            ;;
            ( bz2 | tbz | tbz2 | tz2 )
                _test_archive bzip2
            ;;
            ( xz | txz | lzma | lz | tlz )
                _test_archive xz
            ;;
            ( zst | tzst )
                _test_archive zstd
            ;;
        esac

        [[ $ifn == *.@(tar|tar.*|tgz|taz|tbz|tbz2|tz2|txz|tlz|tzst) ]] &&
            _test_archive tar metadata
    done
}
