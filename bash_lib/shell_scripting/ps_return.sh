: """Check PIPESTATUS and return with the highest value

    Example

      ( exit 3 ) | false | true
      ps_return || return
"""

ps_return() {

    # must read PIPESTATUS as the first command line
    local ps=( "${PIPESTATUS[@]}" )

    [[ ${1-} == @(-h|--help) ]] \
        && { docsh -TD; return; }

    local -i v rs=0
    for v in "${ps[@]}"
    do
        (( v > rs )) && rs=$v
    done

    return $rs
}
