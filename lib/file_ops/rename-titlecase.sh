# dependencies
import_func str_to_words array_match \
    || return

rename-titlecase() {

    : """Change filename words to title-case

        Usage: rename-titlecase {file-name} ...

          - Operates only on file basenames, not the whole path.
          - Ignores some small words, e.g.: 'a', 'an', 'the', 'and', 'at', 'with'.
    """

    [[ $# -eq 0  || $1 == @(-h|--help) ]] &&
        { docsh -TD; return; }

    # words to ignore
    local ign_words=( a an the and yet if to at in or nor with )

    # loop over filenames
    local ofn obn odn \
        obn_words i wd \
        nbn nfn1 nfn2

    for ofn in "$@"
    do
        [[ -e $ofn ]] \
            || { err_msg 3 "file not found: '$ofn'; aborting..."; return; }

        obn=$( basename "$ofn" )
        odn=$( dirname "$ofn" )

        # split filename into array of words
        # - alternative: IFS=$'\n' read -ra obn_words -d '' < <( compgen -W "$obn" )
        str_to_words obn_words "$obn"

        # generate new basename, using uppercase operator
        # - this doesn't ignore articles: nbn=${obn_words[*]@u}
        i=0
        nbn=$obn
        for wd in "${obn_words[@]}"
        do
            # ignore articles
            array_match ign_words "$wd" \
                && (( i > 0 )) \
                && continue

            nbn=${nbn/"$wd"/"${wd@u}"}
            (( ++i ))
        done

        [[ $nbn == "$obn" ]] \
            && continue

        # use a 2-step rename for case-insensitive filesystems (macOS)
        nfn1="$odn/_rn_$nbn"
        nfn2="$odn/$nbn"

        command mv -vi "$ofn" "$nfn1" \
            && command mv -vi "$nfn1" "$nfn2"
    done
}
