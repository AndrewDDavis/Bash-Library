# Desktop Clipboard

[[ -n $( command -v xclip ) ]] &&
    alias paste-xclip="xclip -selection clipboard -o"

[[ -n $( command -v xsel ) ]] &&
    alias paste-xsel="xsel -bo"

[[ -n $( command -v wl-paste ) ]] &&
    alias paste-wl="wl-paste"
