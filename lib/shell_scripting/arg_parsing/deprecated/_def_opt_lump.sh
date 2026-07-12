# these functions are deprecated

_def_opt_lump() {

    [[ $# -eq 0 ]] && {

        docsh -TD """Define variables 'opt' and 'lump' when parsing arguments

        Usage: _def_opt_lump \"\$1\"

        - For an argument like \`-a\`, sets \`opt=a\` and \`lump\` remains unset.
        - For an argument like \`--foo\`, sets \`opt=foo\` and \`lump\` remains unset.
        - For an argument like \`-abcd\`, sets \`opt=a\` and \`lump=bcd\`.
        - For \`--key=val\`, sets \`opt=key\` and \`lump=val\`.
        - If the whole argument is \`-\`, sets \`opt=-\`.
        - If the whole argument is \`--\`, returns 1 without setting \`opt\` or \`lump\`.

        Example

          local opt lump

          while [[ \${1:-} == -* ]]
          do
              _def_opt_lump \"\$1\" || { shift; break; }

              while [[ -n \${opt:-} ]]
              do
                  case \$opt in
                      ( f )  foo=1 ;;
                      ...
                      ( a )  _ap_add_arrvar _andpat \"\${2:-}\" || {
                                 [[ \$? -eq 1 ]] && shift || return
                             } ;;
                      ( * )  break 2  # preserves option arg; consider throwing error ;;
                  esac

                  # next from lump, if any
                  opt=\${lump:+\${lump:0:1}}
                  lump=\${lump:+\${lump:1}}
              done

              shift
              unset opt lump
          done
        """
        return 0
    }

    echo "try _arg_lumper instead"
    return

    case $1 in
        ( -- )
            # end of options
            return 1
        ;;
        ( --* )
            # long option like --foo or --key=val
            opt=${1:2}

            if [[ $opt == *=* ]]
            then
                lump=${opt#*=}
                opt=${opt%%=*}
            fi
        ;;
        ( -* )
            # single-letter option like -a, or lump of them like -abcd
            opt=${1:1:1}
            [[ ${#1} -gt 2 ]] && lump=${1:2}

            # handle -
            [[ -z $opt ]] && opt="-"
        ;;
    esac
}

_split_opt_lump() {

    [[ $# -eq 0 ]] && {

        docsh -TD """Split a positional argument into 'opt' and 'lump' parts

        Usage:  IFS=\$'\\n' read -rd '' opt lump < <( _split_opt_lump \"\$1\" )

        - For an argument like \`-a\`, outputs only \`a\`.
        - For an argument like \`--foo\`, outputs only \`foo\`.
        - For an argument like \`-abcd\`, outputs \`a\` and \`bcd\` on separate lines.
        - For \`--key=val\`, outputs \`key \\n val\`.
        - If the whole argument is \`-\`, outputs only \`-\`.
        - If the whole argument is \`--\`, returns 1 with no output.

        Example

          local opt lump

          while [[ \${1:-} == -* ]]
          do
              IFS=\$'\\n' read -rd '' opt lump < <( _split_opt_lump \"\$1\" )

              while [[ -n \${opt:-} ]]
              do
                  case \$opt in
                      ( f )  foo=1 ;;
                      ...
                      ( a )  _ap_add_arrvar _andpat \"\${2:-}\" || {
                                 [[ \$? -eq 1 ]] && shift || return
                             } ;;
                      ( * )  break 2  # preserves option arg; consider throwing error ;;
                  esac

                  # next from lump, if any
                  opt=\${lump:+\${lump:0:1}}
                  lump=\${lump:+\${lump:1}}
              done

              shift
              unset opt lump
          done
        """
        return 0
    }

    echo "try _arg_lumper instead"
    return


    local opt lump

    case $1 in
        ( -- )
            # end of options
            return 1
        ;;
        ( --* )
            # long option like --foo or --key=val
            opt=${1:2}

            if [[ $opt == *=* ]]
            then
                lump=${opt#*=}
                opt=${opt%%=*}
            fi
        ;;
        ( -* )
            # single-letter option like -a, or lump of them like -abcd
            opt=${1:1:1}
            [[ ${#1} -gt 2 ]] && lump=${1:2}

            # handle -
            [[ -z $opt ]] && opt="-"
        ;;
    esac

    printf '%s\n' "$opt" "${lump:-}"
}

_ap_add_arrvar() {

    [[ $# -eq 0 || $1 == @(-h|--help) ]] && {

        docsh -TD """Like _ap_set_var, but add required arg to array

        Usage: _ap_add_arrvar <var-name> \"\${1-}\" || shift

        Used in arg-parsing, dependency of:

          - _split_opt_lump
          - _def_opt_lump
          - _arg_addto_arrvar

        Hint: call _arg_addto_arrvar instead.
        """
        return 0
    }

    echo "use _arg_addto_arrvar instead"
    return 3

    local -n var=$1     # name-ref to the variable to set

    # get required arg from lump or next arg
    if [[ -n ${lump:-} ]]
    then
        var+=( "$lump" )
        unset lump
        return 0
    elif [[ -n $2 ]]
    then
        var+=( "$2" )
        return 1
    else
        err_msg 3 "missing required arg to add to '$1' for '$opt'"
        return 3
    fi
}
