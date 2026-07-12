# these functions are not well tested, and may be deprecated

_arg_lumper() {

    [[ $# -eq 0 || $1 == @(-h|--help) ]] && {

        docsh -TD """Parse a positional argument by splitting it, or just cycle the lump

        Usage: _arg_lumper opt lump \"\${1:-}\"

        _arg_lumper sets the opt and lump variables in the following ways:

        | Type        | E.g.      |  opt | lump |
        | ----------- | --------- | ---- | ---- |
        | Short Flag  |        -a |    a |      |
        | Long Flag   |     --foo |  foo |      |
        | Lumped Flag |     -abcd |    a |  bcd |
        | Key & value | --key=val |  key |  val |
        | Special     |         - |    - |      |
        | Special     |        -- |   -- |      |

        Moreover, if \`lump\` is set to a non-empty value when _arg_lumper is called,
        \`opt\` will be set to the first character of \`lump\` and \`lump\` will be set
        to the remaining characters, without using the positional argument provided.

        After running _arg_lumper to parse an argument, a case statement should
        follow to take appropriate actions depending on the value of opt. When opt
        indicates that an argument is due, _arg_def should be used to get the value,
        either from the next arg or the lump.

        If _arg_def uses the lump, the lump variable is unset.


        - maybe lump should be set to '-', to indicate that happened? otherwise, I don't
        know how to distinguish btw the two cases, maybe return value

        is it enough to do that and then have this at the end of the loop:

            [[ $lump == '-' ]] && unset lump
            [[ -z ${lump:-} ]] && shift
        done

        ^^^ Do we need 'optarg' as well as lump? The lump case is actually different
            from key=val...
            Or I could set lump to '-' as a 'signal', either here or in _arg_def




        _arg_lumper returns code 0 (true) if there is a non-empty lump, or if the
        first positional arg starts with '-'. Otherwise, it returns 1 (false).


        old text, not sure if this still applies:

        Thus, the first positional argument should only be discarded
        (e.g. using \`shift\`) if \`lump\` is empty or unset, and \`lump\` should be emptied
        or unset if it is used as an argument to an option. This may be accomplished
        using the \`_arg_def\` function, with a check on its return status.

        - Previously, the while loop relied on the first positional arg being set and starting
        with '-', so it needed to be kept (not shifted) until it was fully used (i.e.
        until the lump is empty).
        - Now, the lumper function is called at the top of the loop, so the arg could be
          shifted right away.


        Example

          # Parse command-line arguments
          local opt lump

          while _arg_lumper opt lump \"\$@\"
          do
              case \$opt in
                  ( -- )
                      # end of options (e.g. for a stand-alone function)
                      #shift; break

                      # or pass it on (e.g. for a wrapper function)
                      #opts+=( \$opt )
                  ;;
                  ( f | foo )
                      # short or long flag option
                      # can be used as '-f', '-fghi', or '--foo'
                      foo='True'
                  ;;
                  ( j | jar )
                      # short or long option with argument
                      # can be used as '-j arg', '-jarg', '--jar arg', or '--jar=arg'
                      _arg_def baz || {
                          [[ \$? -eq 1 ]] && shift || return
                      }
                  ;;
                  ( key )
                      # manual long option with arg?
                      # maybe...
                      val=\$lump; unset lump ;;
                  ...
                  ( a )  _ap_addto_arrvar _andpat \"\${2:-}\" || {
                              [[ \$? -eq 1 ]] && shift || return
                          } ;;
                  ( * )
                      # unknown arg, which is normal for a wrapper function
                      #break
                      # ^^^ preserves option arg
                      # consider throwing error instead
                  ;;
              esac

              [[ -z \${lump:-} ]] && shift
          done
        """
        return 0
    }

    [[ $# -lt 3 ]] && {
        err_msg 2 "Usage: _arg_lumper opt lump \"\${1:-}\""
        return 2
    }

    local -n optn=$1 lumpn=$2
    shift 2

    if [[ -n ${lumpn:-} ]]
    then
        # could also test for lumpn being set with [[ -v lumpn ]] (can be empty)

        # next from lump
        optn=${lumpn:0:1}
        lumpn=${lumpn:1}

        # if lumpn is empty, set it to - as a signal?

    elif [[ ${1:-} == -* ]]
    then
        # use positional arg
        case $1 in
            ( - | -- )
                optn=$1
            ;;
            ( --* )
                # long option like --foo or --key=val
                optn=${1:2}

                if [[ $optn == *=* ]]
                then
                    lumpn=${optn#*=}
                    optn=${optn%%=*}
                fi
            ;;
            ( -* )
                # single-letter option like -a, or lump of them like -abcd
                optn=${1:1:1}

                if [[ ${#1} -gt 2 ]]
                then
                    lumpn=${1:2}
                fi
            ;;
        esac

    else
        return 1
    fi
}


_arg_def() {

    [[ $# -eq 0 || $1 == @(-h|--help) ]] && {

        docsh -TD """Define named var from \`lump\` or next positional arg.

        Usage: _arg_def <var-name> lump \"\$@\"

        Returns 0 if the value is taken from \`lump\`, or 1 if taken from next arg.

        Example

          # ... as in _arg_lumper

          case \$opt in
              ( f )  _arg_def foo lump \"\$@\" || shift

          # ...
        """
        return 0
    }

    local -n varn=$1 lumpn=$2     # name-refs
    shift 2

    # get required arg from lump or next arg
    if [[ -n ${lumpn:-} ]]
    then
        varn=$lumpn
        unset lumpn
        return 0

    elif [[ -n ${1:-} ]]
    then
        varn=$1
        return 1

    else
        err_msg 3 "unable to set '${!varn}' from '${!lumpn}' or '\$1'"
        return 3
    fi
}


_arg_addto_arrvar() {

    [[ $# -eq 0 || $1 == @(-h|--help) ]] && {

        docsh -TD """Used in arg-parsing, like _arg_def, but add required arg to array.

        Usage: _ap_add_arrvar <var-name> lump \"\${1:-}\" || shift

        Like _arg_def, returns 0 if the value is taken from \`lump\`, or 1 if taken from
        next arg.
        """
        return 0
    }

    local -n varn=$1 lumpn=$2     # name-refs
    shift 2

    # get required arg from lump or next arg
    if [[ -n ${lumpn:-} ]]
    then
        varn+=( "$lumpn" )
        unset lumpn
        return 0

    elif [[ -n ${1:-} ]]
    then
        varn+=( "$1" )
        return 1

    else
        err_msg 3 "unable to add to '${!varn}' using '${!lumpn}' or '\$1'"
        return 3
    fi
}
