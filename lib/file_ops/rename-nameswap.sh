# deps
import_func str_to_words \
    || return

rename-nameswap() {

    : """Rename file so that \"the file name\" becomes \"name, the file\""

    [[ $# -eq 0  || $1 == @(-h|--help) ]] &&
        { docsh -TD; return; }

    local ofn obn odn \
        obn_words c \
        nbn nfn

    for ofn in "$@"
    do
        obn=$( basename "$ofn" )
        odn=$( dirname "$ofn" )

        # place filename words in array
        # IFS=$'\n' read -ra obn_words -d '' < <( compgen -W "$obn" )
        str_to_words obn_words "$obn"

        # generate new basename
        c=$(( ${#obn_words[@]} - 1 ))
        nbn="${obn_words[-1]}, ${obn_words[*]:0:$c}"

        nfn="$odn/$nbn"

        # move file into place
        /bin/mv -vi "$ofn" "$nfn"
    done
}
