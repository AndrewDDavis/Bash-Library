: compgen-match """List shell features and definitions using compgen.

    Usage: compgen-match <action> [string]

    This function calls \`compgen -A\` with an appropriate keyword, and is typically
    used with the aliases defined in this file, such as \`ls-cmds\` and \`ls-jobs\`.
    The list of available compgen 'actions' for generating completions is available
    on the Bash manpage, in the section on the \`complete\` builtin. Alternatively,
    the list of actions can be generated using \`compgen -A [Tab]\`.

    The function returns with status code 0, unless there were no matches for the
    completion.

    The optional string argument is taken as the start of a completion operation,
    so that matches starting with the string are displayed. Of course, the listed
    output can also be parsed with grep.

    The following aliases for this command have also been defined, and can be used
    as <alias> [string]:

      ls-aliases : List shell aliases
       ls-arrays : List array variables
     ls-bindings : List key-binding names for Readline
     ls-builtins : List available built-in commands
         ls-cmds : List available commands (executables, functions, builtins, ...)
      ls-exports : List exported shell variables
        ls-funcs : List shell function names
   ls-helptopics : List shell help topics
         ls-jobs : List jobs managed by the shell
     ls-keywords : List shell keywords (e.g. if, while, case)
      ls-setopts : List options for the set builtin
       ls-shopts : List options for the shopt builtin
      ls-signals : List signal names
         ls-vars : List defined variables

    To match against variable names and values, refer to the vars-grep function.

    Examples

    ls-vars OPT
    : list all defined variables starting with OPT

    ls-signals | grep -i 'p\$'
    : list signals ending in p
"""

compgen-match() {

    # show docs
    # - check $1 or $2 for -h, if e.g. 'ls-vars -h' is called
    [[ $# -eq 0  || $1 == @(-h|--help)  || ${2-} == @(-h|--help) ]] \
        && { docsh -TD; return; }

    compgen -A "$@"
}
