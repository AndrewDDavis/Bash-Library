: """Transcode audio files to VBR mp3 files using ffmpeg and lame.

    Usage: mp3x [-i ifx] [-o ofx] [-d wdir]

    Supports many input formats, e.g. ogg, flac, wav. See 'ffmpeg -formats'.
    Outputs to q:0 VBR mp3 by default, or 192k m4a if specified.

    Options

      -i ifx  : extension of input files (default 'flac')
      -o ofx  : extension of output files (default 'mp3')
      -d wdir : working dir, default current dir

    Outputs directory of converted files within wdir, e.g. 'mp3-vbr/' or 'm4a-cbr/'.
"""

mp3x() {

    [[ $# -eq 0  ||  $1 == @(-h|--help) ]] &&
        { docsh -TD; return; }

    # return on any command error
    trap 'return' ERR
    trap '
        trap - err return
    ' RETURN

    local ff_cmd=$( command -v ffmpeg ) || {
        err_msg 2 "ffmpeg command not found"
    }

	# Parse args, default to flac files in current dir
    local FLAG OPTARG OPTIND
	local _ifx=flac
	local _ofx=mp3
    local _wd=.
    local _ffopts=()

    while getopts "i:o:d:" FLAG; do
        case $FLAG in
            i )  _ifx=$OPTARG ;;
            o )  _ofx=$OPTARG ;;
            d )  _wd=$OPTARG ;;
            ? )  err_msg 1 "Args: $*" ;;
        esac
    done
    shift $(( OPTIND-1 ))  # remove parsed options, leaving positional args

	# handle metadata of ogg files
	[[ $_ifx == ogg ]] && {
		_ffopts+=( -map_metadata 0:s:0 )
	}

	# output format
    local _od=${_wd%/}/mp3-vbr
	if [[ $_ofx == mp3 ]]
	then
		_ffopts+=( -acodec libmp3lame -aq 0 )
	elif [[ $_ofx == m4a ]]
	then
		_ffopts+=( -c:a aac -b:a 192k )
		_od=${_od/mp3-v/m4a-c}
	else
		err_msg 2 "unknown ofx: '$_ofx'"
	fi

	/bin/mkdir -p "$_od" \
        || err_msg 2 "failed to mkdir '$_od'"


    local _fbn _fn _ofn _skipped=() _proced=()
    for _fn in "${_wd%/}"/*."$_ifx"
    do
        _fbn=$( basename "$_fn" )
        _ofn="$_od"/"${_fbn/%${_ifx}/${_ofx}}"
        if [[ -e $_ofn ]]
        then
            vrb_msg 0 "skipping existing output: '${_ofn}'"
            _skipped+=( "$_ofn" )

        else
            _proced+=( "$_ofn" )

            "$ff_cmd" -i "$_fn"       \
                -vn                   \
                "${_ffopts[@]}"       \
                -v info               \
                "$_ofn"
        fi
    done

    if [[ -v '_skipped[*]' ]]
    then
        printf "\n Skipped:\n"
        printf "    %s\n" "${_skipped[@]}"
    fi

    if [[ -v '_proced[*]' ]]
    then
        printf "\n Wrote to %s:\n" "$_od"
        printf "    %s\n" "${_proced[@]}"

        printf '\n%s\n%s\n%s\n' \
            " Suggested:" \
            " Copy \"cover\" or \"front\" images into $_od, then" \
            "   beet import -t \"$_od\""
    fi
}
