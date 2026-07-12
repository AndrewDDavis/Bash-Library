# Convenient tree-view aliases
# - NB, 'eza -l' prints human-readable sizes, like 'ls -lh'
alias tt="treeza -L2"
alias tta="tt --all"
alias ttd="tt --only-dirs"
alias ttl="tt -lo --no-permissions"
alias ttg="tt -l --git --no-filesize --no-user --no-time --no-permissions"
alias ttad="tt --all --only-dirs"
alias ttal="tt -alo --no-permissions"
alias ttag="tt --all -l --git --no-filesize --no-user --no-time --no-permissions"
