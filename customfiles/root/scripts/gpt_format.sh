#!/bin/sh
#
# Format disks for ZFS and Swap, mount the swap and set the dumpdevice
#
# gpt_format.sh
# 
# example: gpt_format.sh -s 16G -d da0 da1 da2 da3\n"
#

usage() {
    printf "Usage: $0 -s swap_size -d disk1 disk2...\n"
    printf "Example: $0 -s 16G -d da0 da1 da2 da3\n"
    exit 2
}

DEVICES=
SWAPSIZE=

while getopts ":ds:" opt; do
    case $opt in
        d)
	    break
            ;;
        s)
            SWAPSIZE=$OPTARG
            ;;
        : )
            echo "Invalid option: $OPTARG requires an argument" 1>&2
            ;;
        *)
            usage
            ;;
    esac
done
if [ -z ${SWAPSIZE} ]; then
    printf "Invalid Input: Must set swapsize\n"
    exit 2
fi
shift $(($OPTIND - 1))

# The rest of the options are devices
DEVICES=${@}

for DEV in ${DEVICES}; do
	echo "------- Formatting ${DEV} -------"
	gpart destroy -F ${DEV}
	gpart create -s gpt ${DEV}
	gpart add -s ${SWAPSIZE} -t freebsd-swap -l swap ${DEV}
	gpart add -t freebsd-zfs -l zpool ${DEV}
	swapon /dev/${DEV}p1
	dumpon ${DEV}p1
done

exit 0
