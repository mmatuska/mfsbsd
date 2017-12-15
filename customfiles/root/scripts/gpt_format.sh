#!/bin/sh
#
# Format disks for ZFS and Swap, mount the swap and set the dumpdevice
#
# gpt_format.sh -d device 
# 
# example: gpt_format.sh -d da0 -s 16G
#

usage() {
    printf "Usage: $0 -d disk -s swap_size\n"
    printf "Example: gpt_format.sh -d da0 -s 16G\n"
    exit 2
}

DEVICE=
SWAPSIZE=

while getopts "d:s:" opt; do
    case $opt in
        d)
            DEVICE=$OPTARG
            ;;
        s)
            SWAPSIZE=$OPTARG
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

if [ -z ${DEVICE} ]; then
    printf "Invalid Input: Must set device\n"
    exit 2
fi

gpart destroy -F ${DEVICE}
gpart create -s gpt ${DEVICE}
gpart add -s ${SWAPSIZE} -t freebsd-swap -l swap ${DEVICE}
gpart add -t freebsd-zfs -l zpool ${DEVICE}
swapon /dev/${DEVICE}p1
dumpon ${DEVICE}p1

exit 0
