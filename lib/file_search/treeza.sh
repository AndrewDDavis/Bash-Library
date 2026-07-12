# Convenient tree-view aliases are also defined in the env/ directory

treeza() {

    # Directory tree view
    #
    # Usage: treeza [eza-options] [path ...]
    #
    # This function runs 'eza --tree' with the following defaults:
    #
    #   - Files are listed before directories at each level.
    #   - The time column uses a 'month-day hour:min' format for recent files,
    #     and an ISO date format for other files.
    #   - Git directories are ignored (-I '.git').
    #
    # It is recommended to configure eza with a simple colour scheme, instead of
    # the chaotic and distracting one that eza outputs with its long view by
    # default. The theme file is located at '~/.config/eza/theme.yml'.
    #
    # The source file for treeza also adds several aliases for convenient usage:
    #
    #   tt   : treeza -L2
    #   tta  : tt --all
    #   ttd  : tt --only-dirs
    #   ttl  : tt -lo --no-permissions
    #   ttg  : tt -l --git, with all other -l options disabled
    #   ttad : combines tta and ttd
    #   ttal : combines tta and ttl
    #   ttag : combines tta and ttg
    #
    # Refer to the eza manpage for explanations of the options.

    [[ $# -eq 0  || $1 == @(-h|--help) ]] \
        && { docsh -TD; return; }

    local eza_cmd
    eza_cmd=( "$( builtin type -P eza )" ) \
        || return 9

    # tree
    eza_cmd+=( --tree --group-directories-last )

    # time format:
    # - multi-line string, non-recent files get ISO date, recent files get month-day hour:min
    eza_cmd+=( --time-style=$'+%Y-%m-%d\n%m-%d %H:%M' )

    # ignore git dir
    # - NB, can't do just contents, nor add trailing slash, for now; may be a fix coming:
    #   https://github.com/eza-community/eza/issues/1446
    eza_cmd+=( -I '.git' )

    "${eza_cmd[@]}" "$@"
}
