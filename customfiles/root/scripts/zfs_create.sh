#!/bin/sh
#
# Create zfs datasets for triton
#
# zfs_create.sh [-n poolname] devices/partition
# 
# example: zfs_create.sh -n zroot da0p2 da1p2
#

usage() {
	printf "Usage: $0 -n zroot da0p2 da1p2\n" 1>&2
	printf "Example: $0 -n zroot da0p2 da1p2\n" 1>&2
	exit 2
}

if [ $# -eq 0 ]; then
	usage
	exit 2
fi

while getopts ":n:h" opt; do
	case ${opt} in
		h )
			usage
			;;
		n )
			ZPOOL=${OPTARG:-zones}
			;;
		\? )
			echo "Invalid option: $OPTARG" 1>&2
			;;
		: )
			echo "Invalid option: $OPTARG requires an argument" 1>&2
			;;
		*)
			usage
			;;
	esac
done
shift $((OPTIND -1))

# The rest of the arguments are devices
DEVICES=${@}

#
# List pools so that we can abort if a pool with the provided name exists
# already.
#
if ! pools="$(zpool list -Ho name)"; then
	echo "could not list ZFS pools." 1>&2
	exit 1
fi

for pool in $pools; do
	if [ "$pool" == "$ZPOOL" ]; then
		echo "zpool with name ${ZPOOL} already exists." 1>&2
		exit 1
	fi
done

zpool create ${ZPOOL} ${DEVICES}
zfs create -o mountpoint=/zones ${ZPOOL}/zones
zfs create -o mountpoint=/tmp ${ZPOOL}/tmp
zfs create -o mountpoint=/var ${ZPOOL}/var
zfs create -o mountpoint=/opt ${ZPOOL}/opt
zfs create -o mountpoint=/usbkey ${ZPOOL}/usbkey

exit 0
