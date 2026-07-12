git-fzadd() {

    : """git alias to select files to add"

    # maybe this should be a git alias in the git config, like:
    # fza = "!git ls-files -m -o --exclude-standard | fzf -m --print0 --preview "git diff {1}" | xargs -0 git add"

    # git ls-files:
    # -m and -o show modified and untracked (other) files

    # fzf:
    # -m allows multi-select with Tab

    git ls-files -mo --exclude-standard |
        fzf -m --print0 --preview 'git diff {1}' |
        xargs -0 git add
}
