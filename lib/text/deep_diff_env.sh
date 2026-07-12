## Diff file contents in directory trees

# ... TODO

# regular Gnu diff:
#  -N causes missing files to be considered empty
# diff -qr dir1/ dir2/
# diff -qr dir1/ dir2/ | grep ' differ'
# diff -qrN dir1/ dir2/
# diff -qrN --no-dereference --no-ignore-file-name-case dir1/ dir2/ > dirdiff_1.txt

# git diff:
# - nice colour
# git diff --no-index dir1/ dir2/

# meld:
# - can dig down to file diff mode when you see what differs
# meld dir1/ dir2/

# rsync
# - flexible syntax
# - use -n for dry-run, -c for checksums
# rsync -n -rlcv --delete /dir{1,2}/ > dirdiff_2.txt

# maybe check out [diffoscope](https://diffoscope.org/)
