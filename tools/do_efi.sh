#!/bin/sh

WRKDIR=$1

dd if=/dev/zero of=${WRKDIR}/efiboot.img bs=4k count=200 status=none
device=`mdconfig -a -t vnode -f ${WRKDIR}/efiboot.img`
newfs_msdos -F 12 -m 0xf8 /dev/$device
mkdir efi
mount -t msdosfs /dev/$device efi
mkdir -p efi/efi/boot
cp "${WRKDIR}/disk/boot/loader.efi" efi/efi/boot/bootx64.efi
umount efi
rmdir efi
mdconfig -d -u $device
