d2n() {

    : """Wrapper function for Rorden's dcm2niix tool

        Calls dcm2niix with my usual settings on dicoms found in the passed dir

          - Recursively checks 5 levels of depth for dicoms by default
          - If no dir supplied, uses the current directory
          - NIfTI files are output in the current working directory
          - Additional options may be supplied, as long as the search dir is the last argument
    """

    [[ -n ${1-} ]] ||
        set -- '.'

    local d2n_cmd
    d2n_cmd=$( builtin type -P dcm2niix ) \
        || return 5

    "$d2n_cmd" -o '.' -z 'y' -b 'y' -f '%d' "$@"
}
