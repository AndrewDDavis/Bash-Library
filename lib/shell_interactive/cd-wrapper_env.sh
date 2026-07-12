alias cd='cd-wrapper'

cd-wrapper() {

    [[ ${1-} == @(-h|--help) ]] && {

        : """Change the working directory and update the directory stack

        Usage

          cd-wrapper [-L|-P] [path]
          cd-wrapper [+|-]N

        This function is meant to be aliased as 'cd' to combine the best features of
        the cd and pushd built-in commands:

          - When changing directories, all options for 'cd' are allowed. In particular,
            the -L and -P flags may be used to control how the path is interpreted.

          - However, the pushd command is ultimately used to change the current working
            directory (CWD), so that the directory stack is kept up-to-date.

          - The 'cd -' shorthand is allowed, to return to the previous working
            directory.

          - Using 'cd +N' is allowed, which acts like 'pushd +N' to change to a
            directory from the stack. Unlike with pushd, the sign is optional, with
            'N' being synonymous with '+N'.

        Background Notes

          - Unlike when using pushd, the cd built-in command only changes top element
            of the directory stack, visible through the PWD variable, or the command
            'dirs +0'. The cd command does track the last PWD value using OLDPWD, which
            is available using the 'cd -' command.

          - This function supports the -L and -P options of the cd built-in to either
            explicity use the physical path, or allow a path with symlinks, regardless
            of the status of the 'physical' shell option. This allows commands like
            'cd -P l1/..' to be interpreted as expected.

            After the path is interpreted by cd, 'pwd -P' is used to determine the
            physical path it refers to, after dereferencing any symlinks. Refer to the
            docs of the phys_dirpath and _shrtn_cwd functions for more details.

          - This function allows the pushd notation '+N' or '-N' to specify a directory
            using its position on the stack. The stack may be shown with the positions
            using 'dirs -v', which may be aliased to 'dv'.

          - The directory stack is also visible as the DIRSTACK array variable. The
            entries other than [0] may be manipulated manually, but pushd and popd must
            be used to add and remove items.

        Builtin commands to interact with the directory stack

          dirs -v
          : print the directory stack as a numbered column

          dirs +N
          : print nth most recent dir (current is +0)

          dirs -N
          : print nth dir from the end (oldest is -0)

          dirs -c
          : clear the list

          pushd dir
          : add dir to dir-stack, cd to it, then run dirs to show the stack

          pushd -n dir
          : only add dir at position +1, don't cd

          pushd
          : exchange top 2 stack dirs; the former +1 dir will be the new CWD

          pushd +N
          : rotate the stack so the Nth dir is on top, then cd to it

          popd (or popd +0)
          : remove CWD from the list and cd to the dir at position +1

          popd +N
          : remove the Nth dir from the stack
        """
        docsh -TD
        return
    }

    # check for any -L or -P in option arguments
    local i _LP

    for (( i=1; i<=$#; i++ ))
    do
        case ${!i} in
            ( - | -- | [!-]* ) break ;;
            ( --* ) continue ;;
            ( -*L* | -*P* ) _LP=1 ;;
        esac
    done


    local tgt_dir cd_cmd

    if [[ $# -eq 1  && $1 =~ ^(\+|-)?[0-9]+$ ]]
    then
        # +N/-N are sent straight to pushd
        tgt_dir=$1
        shift

        # check for N = +N
        [[ -n ${BASH_REMATCH[1]} ]] ||
            tgt_dir="+$tgt_dir"

        [[ -v _LP ]] && {
            err_msg 5 '-L and -P not supported with +/-N'
            return
        }

    else
        # cd gets all arguments
        cd_cmd=( builtin cd "$@" )
        shift $#

        # use cd + pwd to get the physical version of the intended dir
        # - take care of cd return status
        tgt_dir=$(

            "${cd_cmd[@]}" >/dev/null \
                || exit

            builtin pwd -P

        ) || return
    fi

    pushd "$tgt_dir" >/dev/null
}

# vvv OLD code

#     local n _LP cd_cmd=( builtin cd )
#
#     local flag OPTARG OPTIND=1
#     while getopts ':LPe@' flag
#     do
#         case $flag in
#             ( L | P )
#                 cd_cmd+=( "-$flag" )
#                 _LP=1
#             ;;
#             ( e | @ ) cd_cmd+=( "-$flag" ) ;;
#             ( \? ) err_msg 2 "unknown option: '-$OPTARG'"; return ;;
#             ( : )  err_msg 2 "missing argument for -$OPTARG"; return ;;
#         esac
#     done
#     # preserve '--' for cd
#     n=$(( OPTIND-1 ))
#     [[ ${!n} == '--' ]] &&
#         (( n-- ))
#
#     shift $n

#     # Push current dir onto the stack (quietly)
#     pushd -n "$PWD" >/dev/null
#
#     # If path (from last arg) is relative and exists, prepend ./ to avoid the message due
#     # to matching against CDPATH
#     [[ $# -gt 0  && -d ${@:(-1)}  && ${@:(-1)} =~ ^\.?[a-zA-Z0-9] ]] &&
#     {
#         # debug
#         #echo set -- "${@:1:$(($#-1))}" ./"${@:(-1)}"
#
#         set -- "${@:1:$(($#-1))}" ./"${@:(-1)}"
#     }
#
#     # call shell builtin command cd
#     builtin cd "$@"
