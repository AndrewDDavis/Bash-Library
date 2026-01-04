# dependencies
#import_func seqi \
#    || return

# docs
: """Create local apt package repository

    Scans local directory for deb files, and creates a ./Packages.gz file that
    can be read by apt. Refer to the manpage for dpkg-scanpackages for details.

    Usage: dpkg-localrepo <dir>
"""

dpkg-localrepo() {

    trap 'return' ERR
    trap 'trap - err return' RETURN

    # Parse args
    [[ $# -eq 0  || $1 == @(-h|--help) ]] \
        && { docsh -TD; return; }

    dpkg-scanpackages "$@" \
        | gzip -c -9 > ./Packages.gz
}
