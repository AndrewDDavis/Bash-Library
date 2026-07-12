# dependencies
import_func is_set_array is_idx_array \
    || return

array_reindex() {

    [[ $# -eq 0  ||  $1 == @(-h|--help) ]] && {

        : """Recreate the index of an array, while preserving the order

        Usage: array_reindex [options] <array-name>

        This removes the gaps in a sparse array.

        Options

          -c <n>
          : ignore gaps before index 'n'
        """
        docsh -TD
        return
    }

    # defaults
    local i c=0

    # options
    local flag OPTARG OPTIND=1
    while getopts ':c:' flag
    do
        case $flag in
            ( c ) c=$OPTARG ;;
            ( '?' ) err_msg 2 "Unrecognized: '$OPTARG'"; return ;;
            ( ':' ) err_msg 2 "Missing arg for '$OPTARG'"; return ;;
        esac
    done
    shift $(( OPTIND-1 ))


    # args
    local -n __ari_arrnm__=$1    || return
    shift

    # Require non-empty index array
    is_set_array __ari_arrnm__  && is_idx_array __ari_arrnm__ \
        || { err_msg 3 "non-empty array required, got '${!__ari_arrnm__}'"; return; }


    # step through the array, keeping track of any gaps
    for i in "${!__ari_arrnm__[@]}"
    do
        # ignore earlier values and don't increment c when '-c' was used
        (( i < c )) && continue

        (( i == c )) || {

            # if i > c, there is a gap in the index
            # - move the content
            __ari_arrnm__[c]=${__ari_arrnm__[i]}
            unset '__ari_arrnm__[i]'
        }

        (( ++c ))
    done
}
