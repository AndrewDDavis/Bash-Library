if [[ -n $( command -v eza ) ]]
then
	ls-eza() {
		# Eza tries to replace interactive ls + tree
		# - maybe this alias will help me remember the name
		eza "$@"
	}
fi
