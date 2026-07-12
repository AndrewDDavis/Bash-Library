lsblkx() {
	# Block Devices: lsblk
	# - set display columns and no loop devices
	lsblk -e 7 \
		-o "NAME,RM,VENDOR,SIZE,PTTYPE,PARTFLAGS,FSTYPE,LABEL,MOUNTPOINT" \
		"$@"
}
