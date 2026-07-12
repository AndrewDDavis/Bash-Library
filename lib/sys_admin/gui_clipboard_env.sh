# Desktop Clipboard

if [[ -n $( command -v xclip ) ]]
then
    alias paste-xclip="xclip -selection clipboard -o"
fi

if [[ -n $( command -v xsel ) ]]
then
    alias paste-xsel="xsel -bo"
fi

if [[ -n $( command -v wl-paste ) ]]
then
    alias paste-wl="wl-paste"
fi
