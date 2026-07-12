# Unit testing shell scripts
# TODO: continue reading and making notes from link below.
# - Notes from: https://www.leadingagile.com/2018/10/unit-test-shell-scripts-part-one
# - also see the [Bash Automated Testing System](https://github.com/bats-core/bats-core)
#
# Principles:
# - only test what is _in scope_ for a script; e.g. functionality of external commands
#   is not something to test, but the parsing of the output of those commands is.
# - where necessary, create _mock_ commands for external commands, e.g. a mock `df`
#   command that simply echos the expected output of df, which is aliased to df while
#   the unit test runs.
# - the output of the mock commands is piped around and processed in the same way as the
#   real output of the command would be.

_args_unit_test() {

    # - unit test for arg_lumper and arg_def, sets variables based on arguments provided to
    #   function

    echo '...'

    _test_al() {
        # expected strings
        local x_opt=$1 x_lump=$2
        shift 2

        # number of runs
        local r n=1
        if [[ $1 == -n[0-9]* ]]
        then
            n=${1#-n}
            shift
        fi

        # test
        local tst_str="Testing Args (n=$n): ${*@Q}"

        local opt lump

        for r in $( seq $n )
        do
            _arg_lumper opt lump "$@"
            [[ -z ${lump:-} ]] && shift
        done

        # report
        local rep_str=()

        # we don't distinguish unset vs empty
        [[ -v opt ]] || opt=''
        [[ -v lump ]] || lump=''

        if ! [[ $x_opt == ${opt@Q} ]]
        then
            rep_str+=( "    ${_cfg_r}Expected:${_cfg_d} ${x_opt}" )
            rep_str+=( "         ${_cfg_r}Got:${_cfg_d} ${opt@Q}" )
        fi

        if ! [[ $x_lump == ${lump@Q} ]]
        then
            rep_str+=( "    ${_cfg_r}Expected:${_cfg_d} ${x_lump}" )
            rep_str+=( "         ${_cfg_r}Got:${_cfg_d} ${lump@Q}" )
        fi

        if [[ ${#rep_str[@]} -eq 0 ]]
        then
            printf '%s\n' "${tst_str}" "    ${_cfg_g}Pass:${_cfg_d} ${opt@A} ${lump@A}"
            return 0
        else
            printf '%s\n' "$tst_str" "${rep_str[@]}"
            return 2
        fi
    }

    # flag variables
    _test_al "'a'" "''" -a
    _test_al "'b'" "'cd'" -n2 -abcd
    _test_al "'foo'" "''" --foo
    _test_al "'-'" "''" -
    _test_al "'--'" "''" -n2 -a -- -b
    _test_al "'key'" "'val'" -n2 -a --key=val

    unset -f _test_al
}
