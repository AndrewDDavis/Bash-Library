zip-test() {

    : """Test zip archive integrity"

    [[ $# -eq 0  || $1 == @(-h|--help) ]] &&
    	{ docsh -TD; return; }

    unzip -tq "$@"
}
