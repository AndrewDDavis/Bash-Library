unzip-list() {
    # alias to zip-list
    zip-list "$@"
}

zip-list() {
    : """List zip archive contents"""

    [[ $# -eq 0 ||  $1 == @(-h|--help) ]] &&
    	    { docsh -TD; return; }

    unzip -l "$@"
}
