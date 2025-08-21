# wcurl is an alternative that has more features and is distributed with curl
alias curlw='wcurl'

# docsh curl-dl
# Download a file using 'curl -fLO'
#
# Usage: curl-dl <URL>
#
# Notable curl options:
#
#  -f : fail on HTTP error message > 400
#  -L : follow server URL if it provides a moved location
#  -O : output to a file, using the name from the URL
#  -s : silent (no progress or errors)
#  -S : print errors in silent mode
curl-dl() {

	curl -fLO "$@"
}
