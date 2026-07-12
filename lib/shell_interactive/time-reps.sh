# dependencies
import_func is_int vrb_msg \
	|| return

time-reps() {

	: """Time repetitions of a command

		Usage: time-reps [options] command [args ...]

		Records the time it takes to runs the provided command-line repeatedly 1000
		times (n), then repeats the timed loop a total of 10 times (m). The stdout of
		the command is diverted to /dev/null, to prevent the time of printing to the
		terminal from influencing the results. Only the 'real' time is reported, unless
		only 1 meta-loop is requested.

		For reference purposes, running 1000 iterations of a no-op command typically
		takes ~2 ms on my machine. A very simple builtin command such as 'echo hi' may
		take ~3 ms, while a simple external call such as '/bin/echo hi' may take ~1100
		ms. This implies ~3 us for 1 run of a very simple builtin command, or ~1 ms for
		1 call of an external commmand.

		Often the first meta-iteration takes longer than the next ones, but not always.
		Using the meta-loop with a pipe that sends the inner loop into a subshell seems
		to give more consistent, faster results, compared to repeatedly running the
		timed loop in an interactive terminal session.

		Simple commands work well as input. To test more complex command lines, e.g.
		with redirections, it is necessary to wrap the commands in a function, then
		pass the function call as the command to time-reps. This adds a small amount of
		overhead (~4 ms to run a no-op or simple builtin 1000 times via a function).

		Options

			-n N
			: number of repetitions of the command on the inner loop (default 1000)

			-m M
			: meta-repetitions of the loop (default 10)

			-v
			: print the values of N and M before running the timing

		Examples

		  time-nits echo hi
	"

	[[ $# -eq 0  || $1 == @(-h|--help) ]] \
		&& { docsh -TD; return; }

	# defaults and options
	local -i n=1000 m=10 _verb=1

	local flag OPTARG OPTIND=1
	while getopts ':n:m:v' flag
	do
		case $flag in
			( n ) n=$OPTARG ;;
			( m ) m=$OPTARG ;;
			( v ) (( _verb++ )) ;;
			( : )  err_msg 2 "missing argument for option $OPTARG"; return ;;
			( \? ) err_msg 3 "unknown option: '$OPTARG'"; return ;;
		esac
	done
	shift $(( OPTIND-1 ))

	(( $# > 0 )) || return 2
	is_int -p $n || return 3
	is_int -p $m || return 4

	# define grep cmd
	# TODO: use rematch
	local grep_cmd
	grep_cmd=( "$( builtin type -P grep )" ) \
		|| return 9

	(( m > 1 )) \
		&& grep_cmd+=( real ) \
		|| grep_cmd+=( . )

	vrb_msg 2 "N=$n (inner reps)" \
		"M=$m   (outer meta-reps)"

	# NB, time writes to STDERR
	local i j
	for (( j=0; j<m; j++ ))
	do
		{
			time {
				for (( i=0; i<n; i++ ))
				do
					"$@"
				done
			}
		} 2>&1 1>/dev/null | "${grep_cmd[@]}"
	done
}
