# TODO:
# - document the --grep option and other filters
# - make this a more general-purpose jcw() function?

jc-unit() {

    [[ $# -eq 0  || $1 == @(-h|--help) ]] && {

	    : """Show 100 lines of journalctl output for a systemd unit

	        Usage: jc-unit [jc-opts] <unit>

	        Example:

	          jc-unit dnsmasq
	    "
	    docsh -TD
	    return
    }

	journalctl -n 100 --no-hostname -u "$@"
}
