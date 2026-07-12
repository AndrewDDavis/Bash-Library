if [[ -n $( command -v osascript ) ]]
then
    # macOS
    alias logout-mac="osascript -e 'tell application \"System Events\" to log out'"
fi

if [[ -n $( command -v gnome-session-quit ) ]]
then
    # Gnome
    alias logout-de="gnome-session-quit"
fi
