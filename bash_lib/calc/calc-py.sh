: """Print result of math expression using Python

    Usage: calc-py <expression> [precision]

    Print the result of a mathematical expression using Python, with its math
    library loaded. If no expression is present on the command-line, it will be
    read from standard input. The default precision is 6.

    The math library functionality includes the following:

    - Constants such as pi and e.
    - sqrt(x), pow(x, y), exp(x), log(x, base).
    - sin(x), cos(x), tan(x) (input in radians).
    - degrees(x), radians(x).
    - floor(), ceil(), gcd() (greatest common divisor).
"""

calc-py() {

    # Check input
    (( $# == 0 )) || (( $# > 2 )) || [[ $1 == @(-h|--help) ]] \
        && { docsh -TD; return; }

    [[ -n $( command -v python3 ) ]] \
        || { err_msg 2 "python3 not found"; return; }

    local expr
    expr=$1
    shift

    # precision
    local p
    [[ -v 1 ]] \
        && p=$1 \
        || p=6

    # NB, Python3 has floating point division for '/' by default
    python3 -c "
from math import *
print('{:0.${p}f}'.format(${expr}))
"
}

