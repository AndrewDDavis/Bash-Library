ffmpeg-frames() {

    : """Output video frame(s) as images

    Usage: ffmpeg-frames <infile> <time> ...

    - Time arguments are formatted as [HH]:MM:SS[.nnn], or S[.nnn], in seconds by
      default, unless the unit is specified as ms or us. In both forms, prepending
      with - indicates negative duration. Examples of valid time durations, from
      '\`man ffmpeg-utils\`':
        + '23.189' : 23.189 seconds
        + '200ms' : 200 milliseconds (0.2s)
        + '12:03:45' : 12 hrs, 3 min, and 45 sec
        + '1:00' : 1 min

    - The output format will be '{video-name}-#.jpg'.
    """

    [[ $# -lt 2  || $1 == @(-h|--help) ]] &&
        { docsh -TD; return; }

    # args
    local if ts=()

    if=$1
    shift

    ts=( "$@" )
    shift $#

    local if_noext of i=1 t
    if_noext=${if%.*}

    for t in "${ts[@]}"
    do
        # NB:
        # - could grab more frames, using a diff value for -frames:v ...
        # - if you're interested in frame-rate of the vid:
        #   ffprobe -v 0 -of csv=p=0 -select_streams v:0 -show_entries stream=r_frame_rate infile
        #   e.g. 25/1, which means 25 fps
        # - using -frame_pts true did not work, always 0

        # using a %03d pattern with -start_number so image2 doesn't complain
        of=${if_noext}-'%03d'.jpg

        command ffmpeg -ss "$t" -i "$if" \
            -f image2 -frames:v 1 -q:v 2 \
            -start_number "$i" "$of" \
                || return

        (( ++i ))
    done
}
