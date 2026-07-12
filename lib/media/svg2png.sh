svg2png() {

    [[ $# -eq 0 || $1 == @(-h|--help) ]] && {

        docsh -TD """Convert svg to png

            Uses rsvg-convert, from the librsvg2-bin package

            Usage: svg2png [options] infile.svg outfile.png

            Produces 512 x 512 by default, use -w and -h to change.
        """
        return 0
    }

    local ifn=${@: -2 : 1 }
    local ofn=${@: -1 }
    set -- "${@: 1 : $(( $# - 2 )) }"

    # default size
    local _args=( --keep-aspect-ratio )
    if [[ $# -eq 0 ]]
    then
        _args+=( -w 512 -h 512 )
    else
        _args+=( "$@" )
    fi

    rsvg-convert "${_args[@]}" "$ifn" -o "$ofn"

    # imagemagick seems to fail on this (empty image):
    # convert -background none -size 512x512 infile.svg outfile.png

    # or, using inkscape
    # inkscape -w 1024 -h 1024 input.svg -o output.png
}
