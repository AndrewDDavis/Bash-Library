# dependencies
import_func csi_strvars str_trunc is_int \
    || return

# prefer basename function for speed, but it's not fatal
import_func basename \
    || true

prompt_cwd_or_status() {

    [[ $# -eq 0  || $1 == @(-h|--help) ]] && {

        : """Print string for PS1, depending on return status of previous command

        Usage: prompt_cwd_or_status \$?
        """
        docsh -TD
        return
    }

    # return status
    local -i retstat=$1 \
        || return
    shift

    # generate shortened CWD string
    local scwd
    scwd=$( _shrtn_cwd ) \
        || return 9

    if [[ $retstat -eq 0 ]]
    then
        # Just print the CWD string
        # - newline will be stripped when output is captured
        # - don't prepend with any reset, as colour is set in prompt_colourize
        printf '%s\n' "$scwd"

    else
        # Print string with return status instead of CWD
        # - string length should be the same as scwd
        _ret_statstr ${#scwd} $retstat
    fi
}

__scwd_docs() {

    # keep the docs out of the func defn to keep it lean
    : """Print truncated working directory path for use in PS1

    Usage: _shrtn_cwd [options ...]

    This function uses ~ and truncates PWD in a sensible place, respecting
    PROMPT_DIRTRIM if optimal. It is intended to be used in concert with other shell
    init scripts to set the PS1 prompt string.

    If -P is issued, the physical value of the current working directory (CWD) is
    used, as in 'pwd -P'. Otherwise, the shell's CWD value is used, which may contain
    symlinks. The CWD value is inherited by the shell at initialization, then modified
    by the cd command (or pushd and popd, which internally call cd). Whether the
    physical value is written to PWD also depends on the state of the 'physical' shell
    option. Attempting to directly change the value of PWD or DIRSTACK[0] does not
    change the shell's notion of the CWD.

    It is recommended to set the PWD value to the physical path, to prevent unexpected
    inconsistencies between the prompt and other tools (refer to the notes below). The
    cd-wrapper function is useful to ensure the physical path is used in the prompt.

    In my testing, this function takes ~ 15 ms to execute with a long path on a
    modest machine.

    Options

      -n d : limit the string to \`d\` characters; the default is 20% of the terminal
             width, to a maximum of 24 chars, or 12 chars if the width is unknown.
      -b   : print only the basename of the CWD path, rather than the whole path.
      -L   : the value of PWD is used, wihout resolving symbolic links (default).
      -P   : the physical path of PWD is used, after resolving symbolic links.

    Example

      _shrtn_cwd -n 12 -b

    Notes on -P

    If -P is not used, and the 'physical' shell option is not set, the value of PWD
    written in the prompt may contain symlinks. This can have suprising effects when
    working with tools other than cd, e.g.:

    cd -P /etc
    mkdir -p d1/d2
    ln -s d1/d2 l1
    # now, l1 points to d1/d2
    cd -L l1
    # prompt and PWD show /etc/l1
    # now, with 'cd -L ..', prompt and PWD would return to /etc
    # however 'ls ..' lists the contents of d1
    # also 'mkdir ../d3' creates the directory /etc/d1/d3, not /etc/d3!
    """
    docsh -TD
}

_shrtn_cwd() {

    [[ ${1-} == @(-h|--help) ]] &&
        { __scwd_docs; return; }

    # Defaults and args

    # max string length: default 20% of screen or 24 columns
    local -i clim

    if [[ -n ${COLUMNS-} ]]
    then
        clim=$(( COLUMNS/5 ))

    elif [[ -n $( command -v tput ) ]]
    then
        clim=$(( $( tput cols )/5 ))

    else
        clim=12
    fi

    [[ $clim -gt 24 ]] &&
        clim=24


    local bw=w      # basename or whole path
    local lp=l      # linked or physical CWD


    local flag OPTARG OPTIND=1
    while getopts ":n:bLP" flag
    do
        case $flag in
            ( n ) clim=$OPTARG ;;
            ( b ) bw=b ;;
            ( L ) lp=l ;;
            ( P ) lp=p ;;
            ( \? | : ) return 2 ;;
        esac
    done
    shift $(( OPTIND-1 ))


    # Get CWD path and basename
    # - could also use 'dirs +0', which already uses ~ notation
    local swd swd_bn pwd_cmd

    pwd_cmd=( builtin pwd )

    # physical path or PWD
    [[ $lp == p ]]  &&
        pwd_cmd+=( -P )

    swd=$( "${pwd_cmd[@]}" )
    swd=${swd/#"$HOME"/'~'}

    # sanity check: e.g. for when under a mount point that got disconnected
    [[ -n ${swd-} ]] ||
        return 9

    swd_bn=$( basename "$swd" )


    ### Shorten according to settings

    if [[ $swd == '/' ]]
    then
        # root dir is a special case
        true

    elif [[ $bw == b  || ${#swd_bn} -gt $(( clim-5 )) ]]
    then
        # Only basename considered if requested, or if swd_bn is already long
        # - clim gets a bit of padding in the above comparison to account for '.../'
        swd=$( str_trunc $clim "$swd_bn" )

    else
        # Whole path considered
        local swd_arr trim_dir
        local -i n

        # if DIRTRIM is set, respect it
        [[ -n ${PROMPT_DIRTRIM-} ]] && {

            # should be positive int
            if is_int -p "$PROMPT_DIRTRIM"
            then
                # keep DIRTRIM dirs in addition to ~/..., as Bash would

                # NB, Bash behaviour, using the test: abc='\w'; echo "${abc@P}"
                #
                # - in ~/Scratch/src_exe/d, with PROMPT_DIRTRIM=1:
                #   ~/.../d
                # - in ~/Scratch/src_exe/d, with PROMPT_DIRTRIM=2:
                #   ~/.../src_exe/d
                # - in /etc/apt/apt.conf.d, with PROMPT_DIRTRIM=1:
                #   .../apt.conf.d
                # - in /etc/apt/apt.conf.d, with PROMPT_DIRTRIM=2:
                #   .../apt/apt.conf.d
                #
                # However, I think printing ~/.../ and .../ is superfluous then you're
                # printing untruncated directory names, since a/b is obviously not a
                # full path of the filesystem.

                # create array from path elements
                # - split at /, omitting root dir to avoid an empty swd_arr[0]
                # - e.g. /a/b/c/d should give 4 elements
                # - NB, this read cmd only takes ~ 3 ms... just counting the '/' takes 2 ms
                IFS='/' read -rd '' -a swd_arr < \
                    <( printf '%s\0' "${swd#/}" )

                # don't consider ~/ as a dir when trimming
                [[ ${swd_arr[0]} == '~' ]] &&
                    unset 'swd_arr[0]'

                (( ${#swd_arr[@]} > PROMPT_DIRTRIM )) && {

                    # trim dir is the boundary, remove everything before it
                    trim_dir=${swd_arr[-$PROMPT_DIRTRIM]}

                    # - care needed for PDT=1
                    swd=${swd#*"/${trim_dir}"}
                    swd=${trim_dir}${swd}
                }
            else
                err_msg w "illegal PROMPT_DIRTRIM: '$PROMPT_DIRTRIM'"
            fi
        }

        # truncate as necessary
        (( ${#swd} > clim )) && {

            # shorten the leading path, adding ... as necessary
            # - account for basename, then add it back
            n=$(( clim - ${#swd_bn} ))
            swd=$( str_trunc -s $n "${swd%"${swd_bn}"}" )
            swd=${swd}${swd_bn}
        }
    fi

    printf '%s\n' "$swd"
}

_ret_statstr() {

    : """Usage: _ret_statstr <n> <code>

    - n is the target number of characters for the string
    - code is the return status code of the previous command
    """

    # Define variables for control sequence codes
    #
    # - These CSI codes must be evaluated using printf's %b, since this function writes
    #   into PS1 after they would be interpreted.
    #
    # - For the same reason, not using the -p option here, but must wrap the control
    #   sequences in \001 and \002, since \[ and \] won't be interpreted (as noted at
    #   the [bash faq](https://mywiki.wooledge.org/BashFAQ/053)).
    #
    # - This is easily accomplished using the -d option to csi_strvars.
    #
    # - Another way is to use the variable transformation @P to print a string "like a
    #   prompt", e.g. 'echo "${foo@P}"', which will evaluate escape sequences _and_
    #   \[...\], unlike printf '%b' ... .

    # - these may be defined by a run in prompt_colourize; skip if so
    [[ -n ${_cbo-}  && -n ${_cfg_r-}  && -n ${_crs-} ]] ||
        csi_strvars -pd


    # extra chars in short-cwd vs ret-status value (may be more than 1 digit)
    local -i nchars rs_code n_xchr

    nchars=$1 || return
    rs_code=$2 || return
    shift 2

    n_xchr=$(( nchars - ${#rs_code} ))

    # prepend return status value with a string that provides context
    # - could use a no-break space ($'\u00A0') in places where a regular one would
    #   get stripped away; doesn't seem to be an issue
    local ststr

    if (( n_xchr < 1 ))
    then
        ststr=""
    elif (( n_xchr == 1 ))
    then
        ststr="?"
    elif (( n_xchr < 7 ))
    then
        ststr="?:"
    else
        ststr="status:"
    fi

    # decrement no. of extra chars
    n_xchr=$(( n_xchr - ${#ststr} ))

    if [[ -n $ststr ]]
    then
        # add the style and status code value to the string
        # - make the pre-string red, except any colon
        local c=''
        [[ $ststr == *: ]] &&
            c=':'

        ststr="${_cbo}${_cfg_r}${ststr%:}${_crs}${c}${_cbo}${rs_code}${_crs}"
    else
        # just red-bold the return status
        ststr="${_cbo}${_cfg_r}${rs_code}${_crs}"
    fi

    # pad with spaces as necessary, accounting for [ ... ]
    # - spaces added internally to prevent them getting stripped on return
    local -i wrap_br fs bs i

    (( n_xchr > 3 )) && {

        n_xchr=$(( n_xchr - 4 ))
        wrap_br=1
    }

    (( n_xchr > 0 )) && {

        # split spaces front and back, checking for odd
        fs=$(( n_xchr/2 + n_xchr%2 ))
        bs=$(( n_xchr/2 ))

        # string of spaces to pull from
        local s=''

        for (( i=0; i<fs; i++ ))
        do
            s+=' '
        done

        ststr="${s::$fs}${ststr}${s::$bs}"
    }

    [[ -n ${wrap_br-} ]] && {

        # wrap in [ ... ]
        ststr="${_cbo}[${_crs} ${ststr} ${_cbo}]${_crs}"
    }

    # - prepend a reset so the status string style rules
    printf '%s%s\n' "$_crs" "$ststr"
}
