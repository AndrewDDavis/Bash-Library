# Run Nix with increased verbosity by default
if [[ -n $( command -v nix ) ]]
then
    alias nix="nix -v"
fi
