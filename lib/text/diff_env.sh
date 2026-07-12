# Colourized output
if (( ${TERM_NCLRS:-2} >= 8 )) \
    && diff --color /dev/null /dev/null &>/dev/null
then
    alias diff="diff --color=auto"
fi

# completion for diff variants: same as diff
# found by doing diff -[Tab] in a terminal, then typing Ctrl-\ and running 'complete -p diff'
complete -F _comp_complete_longopt \
    diff-qs \
    diff-u \
    diff-hldiffr \
    diff-g \
    diff-gw \
    diff-dw \
    diff-sbs \
    diff-sbsw \
    diff-mrg-ifdef \
    diff-mrg-quick \
    diff-mrg-patch \
    diff-mrg-sdiff
