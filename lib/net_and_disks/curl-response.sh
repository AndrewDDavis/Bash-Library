# docsh curl-response
# Print HTTP response code using curl
#
# Usage: curl-response <URL>
curl-response() {

	curl -so /dev/null \
		-w '%{response_code}\n' \
		--connect-timeout 15 --max-time 30 \
		"$@"

	# or e.g.:
	#   curl -Is http://www.google.com | head -n 1
	# check for "HTTP/1.1 200 OK" or "HTTP/1.1 302 Found"
}
