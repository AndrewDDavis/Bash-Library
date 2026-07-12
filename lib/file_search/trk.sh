[[ -n $( command -v tracker3 ) ]] && {

    trk() {

        : """Wrapper for tracker3 file search tool and indexer

        Usage: trk ( s | i ) args

        Converts URIs of search results into file paths, and reformats them to be
        easier to visually parse. Also skips passing the output to \`pager\`, the
        way the 'tracker3' command does.

        Commands

        s = search [opts] expr1 ...

            -r : use OR instead of AND btw expressions
            -q : disable showing content snippets
            -f : limit to files
            -s : limit to directories
            -t : limit to documents
            -i/m/v : images/music/video (...)
            --software : desktop files etc

        i = info [opts] file1 ...

            -e : Check whether file is eligible for mining based on config

        See \`man tracker3-search\` etc., or \`tracker3 --help\` for all options.
        """

        [[ $# -eq 0  || $1 == @(-h|--help) ]] &&
            { docsh -TD; return; }

        trap '
            unset -f _t3_run _url2path
            trap - return
        ' RETURN

        local cmd=$1 _v=1
        shift

        _t3_run() {
            # run t3 command on args in a subshell
            (
                [[ $_v -gt 0 ]] && set -x
                tracker3 "$@"
            )
        }

        _url2path() {
            # convert file URI to path using python
            local upath pycmds
            pycmds=( "from urllib.request import url2pathname;"
                     "print(url2pathname(\"$1\"))"
                   )
            upath=$( python3 -c "${pycmds[*]}" )
            printf '%s\n' "$upath"
        }

        # or use my uri2path and path2uri functions

        case $cmd in

            ( s | search )
                local res_line filt

                while IFS='' read -r res_line
                do
                    case $res_line in
                        ( Results: | '' )
                            printf '\n'
                            continue
                        ;;
                        ( *file://* )
                            # convert lines with file URIs to paths
                            # - note line coloration is on, thus \e[32m occurs before file:
                            # - this could be disabled with --disable-color
                            res_line=${res_line#*file://}
                            res_line=$( _url2path "$res_line" )

                            # bold filename, ~ for HOME
                            filt="
                                s|(.*/)([^/]+)\$|\1${_cbo-}\2${_crb-}|
                                s|^${HOME%/}|~|
                            "
                            res_line=$( sed -E "$filt" <<< "$res_line" )
                        ;;
                        ( * )
                            # format snippet
                            res_line=${res_line/#  /: }
                        ;;
                    esac

                    printf '%s\n' "$res_line"

                done < <( _t3_run search "$@" )
            ;;

            ( i | info )
                _t3_run info "$@"
            ;;
        esac
    }
}
