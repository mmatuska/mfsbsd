#!/bin/sh

ISOIMAGE=$1
WRKDIR=$2

# Taken from https://github.com/freebsd/freebsd/blob/master/release/amd64/mkisoimages.sh

# Look for the EFI System Partition image we dropped in the ISO image.
for entry in `etdump --format shell $ISOIMAGE`; do
	eval $entry
	if [ "$et_platform" = "efi" ]; then
		espstart=`expr $et_lba \* 2048`
		espsize=`expr $et_sectors \* 512`
		espparam="-p efi::$espsize:$espstart"
		break
	fi
done

# Create a GPT image containing the partitions we need for hybrid boot.
imgsize=`stat -f %z "$ISOIMAGE"`
mkimg -s gpt \
    --capacity $imgsize \
    -b "$WRKDIR/boot/pmbr" \
    $espparam \
    -p freebsd-boot:="$WRKDIR/boot/isoboot" \
    -o hybrid.img

# Drop the PMBR, GPT, and boot code into the System Area of the ISO.
dd if=hybrid.img of="$ISOIMAGE" bs=32k count=1 conv=notrunc
rm -f hybrid.img

