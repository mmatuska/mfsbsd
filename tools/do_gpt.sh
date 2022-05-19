#!/bin/sh
#
set -e

FSIMG=$1
FSPROTO=$2
FSSIZE=$3
BOOTDIR=$4
EFIIMG=$5
VERBOSE=$6

FSLABEL="auto"


exit_with() {
	local status="$1"
	shift

	if [ -n "$@" ]; then
		echo
		echo "$@"
	fi

	mdconfig -d -u ${unit}
	rm -f ${TMPIMG}

	exit ${status}
}

#Trap the killer signals so that we can exit with a good message.
trap "exit_with 1 'Received signal SIGHUP'" SIGHUP
trap "exit_with 1 'Received signal SIGINT'" SIGINT
trap "exit_with 1 'Received signal SIGTERM'" SIGTERM

if [ ${FSSIZE} -eq 0 -a ${FSLABEL} = "auto" ]; then
	roundup() echo $((($1+$2-1)-($1+$2-1)%$2))
	nf=$(find ${FSPROTO} |wc -l)
	sk=$(du -skA ${FSPROTO} |cut -f1)
	FSSIZE=$(roundup $(($sk*12/10)) 1024)
	IMG_SIZE=$((${FSSIZE}+32))
fi

if [ -n "$VERBOSE" ]; then
  echo "FSIMG ${FSIMG} FSPROTO ${FSPROTO} FSSIZE ${FSSIZE}"
fi

TMPIMG=`env TMPDIR=. mktemp -t ${FSIMG}`

dd of=${FSIMG} if=/dev/zero count=${IMG_SIZE} bs=1k
dd of=${TMPIMG} if=/dev/zero count=${FSSIZE} bs=1k

export unit=`mdconfig -a -t vnode -f ${FSIMG}`
if [ $? -ne 0 ]; then
  echo "mdconfig failed"
  exit 1
fi

if [ -n "$VERBOSE" ]; then
  TIME=time
  set -x
else
  TIME=
fi

gpart create -s gpt ${unit}
gpart add -t freebsd-boot -b 40 -l boot -s 472 ${unit}
gpart bootcode -b ${BOOTDIR}/pmbr -p ${BOOTDIR}/gptboot -i 1 ${unit}
if [ -n "${EFIIMG}" -a -f "${EFIIMG}" ]; then
  gpart add -t efi -s 2m ${unit}
  ${TIME} dd if=${EFIIMG} of=/dev/${unit}p2 bs=128k
fi
gpart add -t freebsd-ufs -l rootfs ${unit}
${TIME} makefs -B little ${TMPIMG} ${FSPROTO}
if [ -f ${EFIIMG} ]; then
  ${TIME} dd if=${TMPIMG} of=/dev/${unit}p3 bs=128k
else
  ${TIME} dd if=${TMPIMG} of=/dev/${unit}p2 bs=128k
fi

if [ -n "$VERBOSE" ]; then
  set +x
fi
if [ $? -ne 0 ]; then
  echo "makefs failed"
  exit_with 1
fi

exit_with 0

