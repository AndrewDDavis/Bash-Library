# Convert markdown text files to different formats
#
# mdconv relies on pandoc. Creates a file with the same name, but adds
# '_converted_' and changes the extension. The extension used for Markdown is
# '.md.txt'.
#
# Usage
#
# RTF/ODT/HTML to Markdown (Commonmark with extensions):
#
#   mdconv md <file.rtf>
#
# Markdown to RTF/ODT/HTML/PDF (use lower-case):
#
#   mdconv rtf <file.md>

mdconv() {

    [[ $# -eq 0 || $1 == @(-h|--help) ]] &&
        { docsh -TD; return; }

    [[ $# -eq 2 ]] || {
        err_msg 2 "Target format and source filename required."
        return 2
    }

    # target format
    local tfmt=$1
    shift

    # source filename
    local ifn=$1
    local ifn_p=${ifn%%.*}
    shift

    _pr_run() (
        set -x
        command "$@"
    )

    case $tfmt in

        ( md )
            _pr_run pandoc -t commonmark_x \
                           -so "${ifn_p}_converted_.md.txt" \
                           "$ifn"
        ;;

        ( rtf | html | odt | pdf )
            _pr_run pandoc -f markdown \
                           -so "${ifn_p}_converted_.${tfmt}" \
                           "$ifn"
        ;;
    esac
}
