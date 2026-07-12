ugrep-quoted() {

    : """Quoted output of filenames with ugrep

    also used -Ij to ignore binary files, and use smart-case on patterns

    for more robust file searching, see the ugrep-files function
    """

    ugrep -Ij -m1 --format='%h%~' "$@"
}

# TODO:
# - incorporate this into ugrep-files
