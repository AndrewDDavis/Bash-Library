img-shrink() {

    : """resizes an image to a lower resolution if it exceeds a set size

    - uses imagemagick's convert
    - preserves aspect ratio
    - only resizes if one of the dimensions exceeds the max
    - writes images with suffix '_shrnk', using jpg quality 88

    Options

    -m : max res (default 2048)
    """
    [[ $# -eq 0 || $1 == -h ]] &&
        { docsh -TD; return; }

    local _m=2048

    if [[ $1 == -m ]]
    then
        _m=$2
        shift 2

    elif [[ $1 == -m* ]]
    then
        _m=${1#-m}
        shift
    fi

    local suf=_shrnk

    local img _c info res res_a
    local ofn fnext fnpre

    for img in "$@"
    do
        # check resolution
        _c=0
        info=$( identify "$img" )
        info=${info#${img} }
        res=$( awk '{print $2}' <<< "$info" )
        res_a=( $( awk -F'x' '{print $1, $2}' <<< "$res" ) )

        for res in "${res_a[@]}"
        do
            [[ $res -gt $_m ]] &&
                _c=1
        done

        [[ $_c -gt 0 ]] || continue

        # filename
        fnpre=${img%.*}
        fnext=${img#${fnpre}}
        ofn="${fnpre}${suf}${fnext}"

        [[ -z $ofn ]] &&
            { err_msg 2 'empty ofn'; return; }

        # suffix '>' resizes only if larger
        convert "$img" -resize "${_m}x${_m}>" -quality 88 "$ofn"
    done
}
