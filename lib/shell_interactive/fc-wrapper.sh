fc-wrapper() {

    : """Re-execute lines from history

        The 'fc' builtin is used to display or re-execute commands from the history
        list. This function is meant to be aliased as fcx or rx, and runs 'fc -s' to
        re-execute commands using this form:

        Usage: rx [pat=rep] [cmd]

          'cmd' : may be an integer, representing a history line, or a string
                  that selects the most recent command starting with those
                  characters. If a negative integer is given, it is interpreted
                  as an offset from the present command.

          'pat' : in the selected command line, each instance of 'pat' is
                  replaced by 'rep'.

        If 'pat' is not used, the selected command is rerun without changes, so that
        'rx abc' reruns the last command starting with 'abc'. The default for 'cmd'
        is -1, so that 'rx' alone reruns the previous command.

        To list commands, use 'fc -l', as:

          fc -l [-nr] [first] [last]

          -n : omit command numbers in listing output.
          -r : reverse the command listing order.

        To open a list of commands in an editor, then run the saved list of
        commands, use:

          fc [-e ename] [-r] [first] [last]

          -e : select editor to use, by default FCEDIT, EDITOR, or vi.
          -r : reverse command listing order.

        The arguments 'first' and 'last' define a series of commands in the history
        list. They may each be a number or a string, and are interpreted in the
        same way as 'cmd' above. The default for first is -16 when listing, so that
        'fc -l' is very similar to running 'history 15'. The default is -1 when
        editing, so running 'fc' alone allows editing of the previous command line.
        To cancel running any commands when in editing mode, clear the file and
        save it.

        Examples

          # rerun the previous command
          rx

          # rerun the 3rd-last command
          rx -3

          # rerun the last man command
          rx man

          # list the last 10 commands
          fc -l -10

          # list 5 commands starting from 25 commands back
          fc -l -25 -21

          # list the commands since man was last run
          fc -l man

          # list the most recent commands from man to echo, inclusive
          fc -l man echo

          # edit a list of the last 5 commands, then run the saved list
          fc -5
    """

    [[ $# -gt 0  && $1 == @(-h|--help) ]] &&
        { docsh -TD; return; }

    fc -s "$@"
}
