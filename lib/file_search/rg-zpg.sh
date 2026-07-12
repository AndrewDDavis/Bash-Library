rg-zpg() {

    : """search with ripgrep, open in pager"

    # - open in vs-code with code -g "$fn:$ln"

    local result fn ln

    result=$(
        rg --ignore-case --color=always --line-number --no-heading "$@" |
            fzf --ansi \
                --color 'hl:-1:underline,hl+:-1:underline:reverse' \
                --delimiter ':' \
                --preview "bat --color=always {1} --theme='Solarized (light)' --highlight-line {2}" \
                --preview-window 'up,60%,border-bottom,+{2}+3/3,~3'
    ) || return

    # parse output for filename and line-number
    fn=${result%%:*}
    ln=${result#*:}
    ln=${ln%%:*}

    [[ -z $fn ]] ||
        ${PAGER:-less} +"$ln" "$fn"
}
