#!/bin/sh

RELEASE=10.0-RELEASE
#RELEASE=`uname -r`
ARCH=amd64
#ARCH=`uname -m`


if [ "$1" = "nox" ]; then
	NOX=1
fi
if [ "$2" = "dtrace" ]; then
	DTRACE=1
fi
if [ "${NOX}" = "1" ]; then
	IMAGE_PREFIX=NOX
else
	IMAGE_PREFIX=PERSONAL
fi
if [ ! -d /cdrom ]; then
	/bin/mkdir -p /cdrom >/dev/null 2>&1
fi
if [ ! -d /cdrom/usr/freebsd-dist ]; then
	echo Please mount a FreeBSD iso at /cdrom
	exit 1
fi
/usr/bin/find tmp -type l -exec /bin/chflags -h nosunlink {} \;
/bin/rm tmp/.install* tmp/.boot_done tmp/.co* tmp/.extract_done tmp/.fbsddist_done tmp/.mfsroot_done tmp/.p* tmp/.gen* tmp/.gpg*
/bin/rm -r tmp/dist
/bin/rm -r tmp/disk
/bin/rm -r tmp/mfs
/bin/rm ${IMAGE_PREFIX}*.iso
/bin/rm ${IMAGE_PREFIX}*.img
/bin/rm ${IMAGE_PREFIX}*.tar
if [ ! -e tools/pkg-static ]; then
	/bin/cp -a `which pkg-static` tools/pkg-static || exit 1
fi


if [ "$2" = "iso" -o "$2" = "all" ]; then
	/usr/bin/make iso \
		RELEASE=${RELEASE}  ARCH=${ARCH} \
		IMAGE_PREFIX=${IMAGE_PREFIX} \
		MFSROOT_MAXSIZE=999m \
		KEYCFG="mfsbsdonly all $3" \
		PKGNG=1 \
		SE=1 || exit 1
fi
if [ "$2" = "imgtar" -o "$2" = "all" ]; then
	/usr/bin/make tar \
		RELEASE=${RELEASE}  ARCH=${ARCH} \
		IMAGE_PREFIX=${IMAGE_PREFIX} \
		MFSROOT_MAXSIZE=999m \
		KEYCFG="mfsbsdonly all $3" \
		PKGNG=1 \
		SE=1 || exit 1
	if /sbin/sysctl security.jail.jailed | /usr/bin/grep 0 >/dev/null 2>&1 ; then
		DOFSSIZE=$(( `ls -l ${IMAGE_PREFIX}-${RELEASE}-${ARCH}.tar | awk '{print $5}'` / 1000 ))
		if [ -n "${DOFSSIZE}" ]; then
		/usr/bin/make image \
			RELEASE=${RELEASE}  ARCH=${ARCH} \
			IMAGE_PREFIX=${IMAGE_PREFIX} \
			MFSROOT_MAXSIZE=999m \
			DOFSSIZE=${DOFSSIZE} \
			KEYCFG="mfsbsdonly all $3" \
			PKGNG=1 \
			SE=1 || exit 1
		fi
	fi
fi
/bin/chmod 644 ${IMAGE_PREFIX}*.iso
/bin/chmod 644 ${IMAGE_PREFIX}*.img
/bin/chmod 644 ${IMAGE_PREFIX}*.tar
