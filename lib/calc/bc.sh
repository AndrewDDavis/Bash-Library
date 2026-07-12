bc() {

	# enable math functions by default
	#
	# - doesn't seem to make any difference to execution time for simple calcs
	# - has the side-effect of setting the scale to 20

	command bc --mathlib "$@"
}
