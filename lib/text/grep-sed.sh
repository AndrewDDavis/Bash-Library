# Use sed to mimic grep
# - this supports literal escape chars (\t, \n, ...) on all platforms
# - note there isn't a cross-platform way to do case-insensitive sed
#   matching, Gnu has `/.../I` and BSD has `/.../i`.
grep-sed()   { sed -n  "/$@/  p"; }
egrep-sed()  { sed -nE "/$@/  p"; }
egrepi-sed() { sed -nE "/$@/I p"; }
