# func-rename
# copy function to a new name
#
#   Usage: func-rename <oldname> <newname>
#
# Solution source: [QA](https://stackoverflow.com/a/18839557)

func-rename() {

    trap 'return' ERR
    trap 'trap - err return' RETURN

    (( $# != 2 )) || [[ $1 == @(-h|--help) ]] \
        && { docsh -TD; return; }

    test -n "$( declare -f "$1" )"

    # NB, _ takes on the last arg of the prev foreground simple command
    eval "${_/$1/$2}"

    unset -f "$1"
}
