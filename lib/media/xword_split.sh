# MuTool process PDF
xword_split() {

    [[ $# -eq 0  || $1 == @(-h|--help) ]] && {

        docsh -TD """Split a large (newspaper) page into 4 quadrants

            Usage: xword_split <full-page.pdf>

            Outputs:

              - xword_pages.pdf with each quadrant as a separate page.
              - xword_kenyptic.pdf with only quadrants 3 and 4.
        """
        return 0
    }

    local _of1=xword_pages.pdf
    local _of2=xword_kenyptic.pdf

    # reference variable loop to add a number suffix
    declare -n _of
    extglob_reset=$(shopt -p extglob)
    shopt -s extglob

    for _of in _of1 _of2
    do
        local -i i=1
        while [[ -e $_of ]]
        do
            i=i+1
            _of=${_of/%*([0-9]).pdf/${i}.pdf}
        done
    done
    $extglob_reset

    # split the page into quadrants
    mutool poster      \
           -y 2 -x 2   \
           "$1"        \
           "$_of1"

    # extract relevant pages
    mutool merge       \
           -o "$_of2"  \
           "$_of1" '3,4'

    printf 'Wrote %s and %s.\n' "$_of1" "$_of2"
}

