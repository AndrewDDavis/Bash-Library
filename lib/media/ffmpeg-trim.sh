ffmpeg-trim() {

    : """Trim video file, optionally without re-encoding

    Usage

      ffmpeg-trim [-C] <infile> <start> <duration> <outfile>

    Options

      -C : copy input to output, without re-encoding (see note)

    Notes

    - Time arguments are formatted as [HH]:MM:SS[.nnn], or S[.nnn], in seconds by
      default, unless the unit is specified as ms or us. In both forms, prepending
      with - indicates negative duration. Examples of valid time durations, from
      '\`man ffmpeg-utils\`':
        + '23.189' : 23.189 seconds
        + '200ms' : 200 milliseconds (0.2s)
        + '12:03:45' : 12 hrs, 3 min, and 45 sec
        + '1:00' : 1 min

    - If stream copy is used to avoid re-encoding, the nearest seek point before the
      start will be chosen. Otherwise, the video is transcoded, and times are
      accurately reproduced (as long as -accurate_seek is enabled, which is the
      default).

    - The output format will be guessed from the file extension.

    - All other arguments will be passed to ffmpeg as output file options, i.e.
      before the output file argument.
    """

    [[ $# -eq 0  ||  $1 == @(-h|--help) ]] &&
        { docsh -TD; return; }

    local copy_args=()
    [[ $1 == -C ]] && {
        copy_args=( -codec copy )
        shift
    }

    # args
    local if of s d

    of=${@:(-1)}
    d=${@:(-2):1}
    s=${@:(-3):1}
    if=${@:(-4):1}
    set -- "${@:1:$#-4}"

    # e.g. ffmpeg -i 00001.mts -ss 00:00:27 -t 00:00:11 -codec copy 00001.mp4
    ffmpeg -i "$if" -ss "$s" -t "$d" "${copy_args[@]}" "$@" "$of"
}
