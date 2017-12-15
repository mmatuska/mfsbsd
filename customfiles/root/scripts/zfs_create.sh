#!/bin/sh
#
# Create zfs datasets for triton
#
# zfs_create.sh [-n poolname] -d devices 
# 
# example: zfs_create.sh -n zroot -d da0p2 da1p2
#

while getopts ":n:d" opt; do
  case ${opt} in
    n )
      ZPOOL=${OPTARG:-zroot}
      ;;
    d )
      break
      ;;
    \? )
      echo "Invalid option: $OPTARG" 1>&2
      ;;
    : )
      echo "Invalid option: $OPTARG requires an argument" 1>&2
      ;;
  esac
done
shift $((OPTIND -1))

# The rest of the options are devices
DEVICES=${@}

if [ $(zpool list -o name | awk 'NR != 1 { print $1 }') == ${ZPOOL} ]; then
	echo "zpool with name ${ZPOOL} already exists." 1>&2
	exit 1
fi

zpool create ${ZPOOL} ${DEVICES}
zfs create -o mountpoint=/triton ${ZPOOL}/triton
zfs create -o mountpoint=/tmp ${ZPOOL}/tmp
zfs create -o mountpoint=/var ${ZPOOL}/var


exit 0
