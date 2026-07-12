calc-awk() {

    : """Print result of math expression using awk

    Usage: calc-awk [options] <expression> ...

    If multiple expressions are provided, the result of the last is printed. This can
    be useful for evaluating intermediate results (see example).

    The mawk implementation of awk makes several mathematical functions available,
    including:

        sin(x) : Sine function (x in radians)
        cos(x) : Cosine function (x in radians)
    atan2(y,x) : Arctan of y/x between -pi and pi
        exp(x) : Exponential function (e^x)
        log(x) : Natural logarithm of x
       sqrt(x) : Square root of x
        rand() : Returns a random number between zero and one

    Options

      -v <var=value>
      : Set variables to be referenced in the expression. May be used multiple times.

      -f <fmt>
      : Set format string of the output for printf. By default, '%.6g', unless the
        result is an exact integer.

      -i
      : Format output as integer.

    Examples

      # cube-root of 12, with precision of 3
      calc-awk -f '%.3f' '12^(1/3)'

      # integer-rounded result of 7/3
      calc-awk -i -v 'a=3' -v 'b=7' 'b/a'

      # sine of pi/4
      calc-awk 'pi=atan2(0, -1)' 'sin(pi/4)'
    """

    # defaults and option parsing
    local _fmt='%.6g' awk_cmd

    awk_cmd=( "$( builtin type -P awk )" ) \
        || return 9

    local flag OPTARG OPTIND=1
	while getopts ':v:f:ih' flag
	do
		case $flag in
			( f )
				_fmt=$OPTARG
			;;
			( v )
				awk_cmd+=( -v "$OPTARG" )
			;;
			( i )
				_fmt='%.0f'
			;;
			( h )
                docsh -TD
                return
			;;
			( \? )
		    	err_msg 2 "unknown option: '-$OPTARG'"
		    	return
			;;
			( : )
		    	err_msg 3 "missing argument for -$OPTARG"
		    	return
			;;
		esac
	done
	shift $(( OPTIND-1 ))

    awk_cmd+=( -v "_fmt=$_fmt" )

    (( $# > 0 )) ||
        { err_msg 4 "missing expression"; return; }


    # awk script
    local ascr exprs

    # prepend print command to the last expression
    set -- "${@:1:$#-1}" "print ${!#}"
    exprs=$( printf '%s\n' "$@" )

    # - NB, awk lacks the ability to evaluate a string variable as an expression,
    #   so the variable is expanded directly into the script
    ascr="
        BEGIN {
            OFMT = _fmt
            $exprs
        }
    "

    "${awk_cmd[@]}" "$ascr"
}
