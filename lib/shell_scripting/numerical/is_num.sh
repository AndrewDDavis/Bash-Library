# awk way (Bourne)
is_num () {

    : """check for any valid number

    example

    if is_num \"\$var\"
    then
        echo \"\$var is a number\"
    else
        echo \"negatory\"
    fi
    """

    local s=$1
    shift

    local awks='
        BEGIN {
            r = "^[-+]?([0-9]+\.?|[0-9]*\.[0-9]+)$"

            # match returns 0 for no match
            c = match(s, r)

            exit !c
        }
    '

    awk -v "s=$s" -- "$awks"
    return $?
}

# or, posix shell

# case ${var#[-+]} in
#     ( '' )
#         printf 'var is empty\n';;
#     ( . )
#         printf 'var is just a dot\n';;
#     ( *.*.* )
#         printf '"%s" has more than one decimal point in it\n' "$var";;
#     ( *[!0123456789.]* )
#         printf '"%s" has a non-digit somewhere in it\n' "$var";;
#     ( * )
#         printf '"%s" looks like a valid float\n' "$var";;
# esac >&2
