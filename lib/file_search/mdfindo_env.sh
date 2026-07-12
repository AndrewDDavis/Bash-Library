# mdfind on macOS
if [[ $( uname -s ) == Darwin  && -n $( command -v mdfind ) ]]
then
    alias mdfindo="mdfind -onlyin"
fi
