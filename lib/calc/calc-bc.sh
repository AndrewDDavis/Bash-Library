calc-bc() {

    : """Print result of math expression using bc

    Usage: calc-bc [options] [--] <expression> ...

    This function prints the result of one or more mathematical expressions using the
    'bc -l' command. If no expressions are present on the command-line, they will be
    read from standard input.

    The main convenience of using this function, rather than calling bc directly, is
    that the expression is evaluated with precision 20 first, before printing the
    result using the desired precision (default scale of 6).

    Multiple statements may be provided by using multiple arguments, as a multi-line
    string, or by separating them using ';'. If multiple statements are used, the
    result of the last expression is printed at the desired precision. This can be
    useful for defining variables or functions in earlier arguments, then providing an
    expression the uses them at the end (see example below).

    Functions from the standard math library may be used, which include:

        s(x) : Sine function (x in radians)
        c(x) : Cosine function (x in radians)
        a(x) : Arctangent of x (returns radians)
        e(x) : Exponential function (e^x)
        l(x) : Natural logarithm of x
      j(n,x) : Bessel function of integer order n of x

    Options

      -i
      : Format output as integer.

      -s N
      : Set the 'scale' for the result, which represents the number of decimal places.

      -f <fmt>
      : Instead of getting bc to print the result with the desired scale, round the
        high-precision result from bc using printf with the indicated format.

        If an empty argument is passed to -f, '%.6g' will be used, although the -i and
        -s option flags are also respected in that case.

    Examples

      # cube-root of 12, with precision of 3
      calc-bc -s 3 '12^(1/3)'

      # integer-rounded result of 7/3
      calc-bc -i 'a=3' 'b=7' 'b/a'

      # calculate the value of pi to 10 decimal places
      calc-bc -s10 '4*a(1)'

      # sine of pi/4, with precision 4
      calc-bc -f '%.4f' 'pi=4*a(1)' 's(pi/4)'

    Background

    The following code illustrates the main functionality of calc-bc:

        bc -l <<< '[a=b ...]; x_=( expr ); scale=6; x_/1'

    As bc evaluates expressions, it prints the result unless the expression was a
    variable assignment, function definition, or void function. calc-bc defines a
    variable using the last expression passed on the command line, which is evaluated
    at high precision. It then prints the result at the desired scale.

    Unfortunately, bc was designed with an interactive interface in mind, so it
    evaluates expressions with the precision setting as they are encountered. This
    can lead to grossly incorrect results for non-interactive expressions, as these
    examples illustrate:

        bc -l <<< 'scale=2; (7/116)*100'
        # 6.00 (wrong)
        bc -l <<< 'x=(7/116)*100; scale=2; x/1'
        # 6.03 (correct)
    """

    # defaults and option parsing
    local _sc=6 _fmt

    local flag OPTARG OPTIND=1
	while getopts ':f:is:h' flag
	do
		case $flag in
			( f )
				_fmt=$OPTARG
			;;
			( i )
				_sc=0
			;;
			( s )
				_sc=$OPTARG
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

    # check for empty or erroneous fmt
    if [[ -v _fmt ]]
    then
        [[ -z $_fmt ]] &&
            _fmt="%.${_sc}g"

        [[ $_fmt == *%* ]] ||
            { err_msg 4 "format missing '%': '$_fmt'"; return; }
    fi

    # statements to be run by bc
    # - this will be a multi-line string generated from the arguments or STDIN
    # - earlier statments should be variable assignments, func defns, etc.
    local bc_cmd bc_script

    bc_cmd=( "$( builtin type -P bc )" -l ) \
        || return 9

    if (( $# > 0 ))
    then
        bc_script=$( printf '%s\n' "$@" )

    else
        bc_script=$( < /dev/stdin )
    fi

    # - ensure statements are split into lines
    bc_script=${bc_script//';'/$'\n'}

    # - strip any trailing newline
    bc_script=${bc_script%$'\n'}

    if [[ -v _fmt ]]
    then
        # use printf to truncate the output
        local bc_out

        # debug
        # decp bc_cmd bc_script _fmt

        bc_out=$( "${bc_cmd[@]}" <<< "$bc_script" )

        # very large numbers are split across multiple lines
        bc_out=${bc_out//$'\\\n'/}

        printf "$_fmt"'\n' "$bc_out"

    else
        # manipulate the last line to get the desired precision
        # - NB, '.*' is greedy
        local s1 s2
        if [[ $bc_script =~ ^(.*$'\n')(.*)$ ]]
        then
            s1=${BASH_REMATCH[1]}
            s2=${BASH_REMATCH[2]}
        else
            # single-line script
            s1=
            s2=$bc_script
        fi

        bc_script=$s1'x_=('$s2')'$'\n'
        bc_script+="scale=$_sc; x_/1"

        # debug
        # printf >&2 '%s\n' "${bc_cmd[*]}" '<<<' "$bc_script" ''

        "${bc_cmd[@]}" <<< "$bc_script"
    fi
}

