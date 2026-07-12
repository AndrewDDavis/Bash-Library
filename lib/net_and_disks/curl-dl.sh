# docsh curl-dl
# Download a file using curl, with sane defaults
#
# Usage: curl-dl <URL ...>
#
# Notable curl options:
#
#  -f : fail on HTTP error message > 400
#  -L : follow server URL if it provides a moved location
#  -O : output to a file, using the name from the URL
#  -J : use server-specified filename if available
#  -s : silent (no progress or errors)
#  -S : print errors in silent mode
#
# NB, This uses similar options to the wcurl command, which is distributed
# with the curl binary.

curl-dl() {

	command curl -fLOJ --remote-name-all --retry 5 \
	    --no-clobber --remote-time \
	    "$@"
}

# docsh curl-dlo
# Download a file with curl, specifying an output directory
#
# This command calls the curl-dl function.
#
# Usage: curl-dlo <output-dir> <URL ...>

curl-dlo() {

    (( $# > 1 )) \
        || { docsh -TD; return 9; }

    curl-dl --output-dir "${1:?}" "${@:2}"
}
