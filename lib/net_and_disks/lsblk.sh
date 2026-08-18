lsblkx() {

	# List block Devices using lsblk
	# - set display columns and exclude loop devices

	lsblk -e 7 \
		-o "NAME,RM,VENDOR,SIZE,PTTYPE,PARTFLAGS,FSTYPE,LABEL,MOUNTPOINT" \
		"$@"
}
