# less pager
# - maintained by [Nudelman](https://github.com/gwsw/less)

### Consider alternatives:
# - bat pager with syntax highlighting: https://github.com/sharkdp/bat
# - moar

### Less configuration for the keyboard shortcuts also occurs in the file at ~/.config/lesskey

### Interesting options:
#
#   -a : Search skips current screen to show next
#   -i : ignore case in search, unless it contains uppercase letters
#   -F : quit immediately if file fits on one screen
#   -j / --jump-target=n : target line is n lines (or fraction) from top
#   -J : show status column on the left (for search and marks)
#   -M : longer prompt including current line position
#   -N : show line numbers
#   -R : output ANSI colour sequences so the terminal renders them
#   -S : long lines are chopped (truncated) rather than wrapped
#   -w : highlight the first unread line after movement
#   -X : Disable termcap init/deinit (don't clear screen on return)
#   --buffers   : max RAM to allocate per file, in kB (default 64)
#   --incsearch : search as you type (tried this, found it counter-intuitive)
#   --line-num-width : min width of line no column (default 7)
#   --use-color : use colour in the interface; change them with --color=xab
#   --tabs      : multiple of cols for tab stops
#   --shift     : num. of cols to scroll with L/R arrow keys

# Set default options
# - note git uses -FRX if this is not set
export LESS="-iJMR --buffers=1024 --jump-target=.2 --tabs=4 --shift=4"

# Colours
if (( ${TERM_NCLRS:-2} >= 8 ))
then
    # - colour specs must be terminated with '$' in the LESS variable
    # LESS="$LESS --use-color --color=Pwk\$ --color=Ewy\$"
    # - vvv returning to default colours, not that I fixed terminal colour settings

    LESS="$LESS --use-color"
fi

# less search history file location
export LESSHISTFILE="${XDG_DATA_HOME:-$HOME/.local/share}"/less/lesshst

# Important commands related to search:
#   Esc-u  : clear search highlighting
#   Esc-U  : clear search highlighting, search string, and status column marks
#   Ctrl-k : search but keep position
#   Ctrl-f : start search at first line of first file on cmd line
#   Ctrl-w : wrap search in current file
#   Ctrl-r : don't interpret regex metacharacters

# Editor called by less using the :v command
# default '%E ?lm+%lm. %g', where %E comes from VISUAL or EDITOR
[[ -n $( command -v micro ) ]] &&
    export LESSEDIT='micro ?lm+%lm. %g'
