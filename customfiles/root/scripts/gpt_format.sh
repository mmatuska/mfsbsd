#!/bin/sh
#
# Format disks for ZFS and Swap, mount the swap and set the dumpdevice
#
# gpt_format.sh
# 
# example: gpt_format.sh -s 16G da0 da1 da2 da3\n"
#

usage() {
	printf "Usage: $0 -s swap_size disk1 disk2...\n" 1>&2
	printf "Example: $0 -s 16G da0 da1 da2 da3\n" 1>&2
}

invalid() {
	fmt="Invalid Input: $1\\n"
	shift

	printf "$fmt" "$@"
}

if [ $# -eq 0 ]; then
	usage
	exit 2
fi

DEVICES=""
SWAPSIZE=""

while getopts ":s:h" opt; do
	case $opt in
		h)
			usage
			exit 1
			;;
		s)
			SWAPSIZE=$OPTARG
			;;
		\? )
			usage
			exit 1
			;;
		: )
			echo "Invalid option: $OPTARG requires an argument" 1>&2
			;;
		*)
			usage
			exit 1
			;;
	esac
done
if [ -z ${SWAPSIZE} ]; then
	invalid 'Must set swapsize'
	exit 2
fi
shift $(($OPTIND - 1))

# The rest of the arguments are devices
DEVICES=${@}

#
# Before we do anything destructive, make sure GEOM is, on some level, aware
# of each specified device.
#
for DEV in ${DEVICES}; do
	if ! geom disk status ${DEV} >/dev/null; then
		invalid 'device "%s" not found in "geom disk status"' ${DEV}
		exit 3
	fi
done

for DEV in ${DEVICES}; do
	echo "------- Formatting ${DEV} -------"

	#
	# Destroying the partition table will fail if this device does not yet
	# have one.  This results in an unhelpful cosmetic wart ("Invalid
	# argument"), so we throw the failure message out for now.
	#
	gpart destroy -F ${DEV} 2>/dev/null

	gpart create -s gpt ${DEV}
	gpart add -s ${SWAPSIZE} -t freebsd-swap -l swap ${DEV}
	gpart add -t freebsd-zfs -l zpool ${DEV}
	swapon /dev/${DEV}p1
	dumpon ${DEV}p1
done

exit 0
