if [[ -n $( command -v subl ) ]]
then
    subl-diff() {

        : """Diff files in Sublime-Text using the Compare-Side-by-Side plugin

            Usage: subl-diff <fileA> <fileB>
        """

        [[ $# -eq 2 ]] \
            || { docsh -TD; return; }

        # ensure absolute paths, necessary for sbs_compare 1.24
        local f1=$1 f2=$2
        shift 2

        [[ $f1 == /* ]] \
            || f1=$PWD/$f1

        [[ $f2 == /* ]] \
            || f2=$PWD/$f2

        subl --command "sbs_compare_files {\"A\":\"${f1}\", \"B\":\"${f2}\"}"
    }
fi
