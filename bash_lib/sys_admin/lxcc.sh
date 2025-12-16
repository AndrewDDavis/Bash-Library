# test whether we're inside a container:
# - this works, but only root can read /proc/1/environ:
#   sudo grep -a '^container=' /proc/1/environ
#   # e.g.: container=lxc
# - this works, but doesn't say what kind of container:
#   grep kthreadd /proc/2/status 2>/dev/null
#   # or
#   ps -o comm= -p2 | grep kthreadd

if ! grep -q kthreadd /proc/2/status 2>/dev/null
then
    # test socket existence (root required)
    if sudo -n true 2>/dev/null \
        && sudo /bin/test -e /root/lxd/termina_lxd.socket
    then
        lxcc() {

            : """Administer LXD from a guest container"

            sudo LXD_SOCKET=/root/lxd/termina_lxd.socket lxc "$@"
        }
    fi
fi
