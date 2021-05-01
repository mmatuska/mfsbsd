#!/bin/sh
set -e
BASE=/tmp/freebsd-dist
RELEASE=${RELEASE:-13.0-RELEASE}
DOWNLOAD_URL=http://ftp.freebsd.org/pub/FreeBSD/releases/amd64/${RELEASE}
while getopts b:r: opt
do
	case $opt in
		b) ACTION="${OPTARG}";;
		r) RELEASE="${OPTARG}";;
	esac
done
if [ "${ACTION}" = "prepare" ]
then
	mkdir -p ${BASE}
	fetch -m -o ${BASE}/base.txz ${DOWNLOAD_URL}/base.txz
	fetch -m -o ${BASE}/kernel.txz ${DOWNLOAD_URL}/kernel.txz
	if [ -x tools/roothack/roothack ]
	then
		cd tools/roothack && make depend && make
	fi
elif [ "${ACTION}" = "build-std" ]
then
	make clean V=1
	make iso V=1 RELEASE=${RELEASE} BASE=${BASE} ROOTHACK=1
	make V=1 RELEASE=${RELEASE} BASE=${BASE} ROOTHACK=1
elif [ "${ACTION}" = "build-se" ]
then
	make clean V=1
	make iso V=1 RELEASE=${RELEASE} BASE=${BASE} ROOTHCK=1 SE=1
	make V=1 RELEASE=${RELEASE} BASE=${BASE} ROOTHACK=1 SE=1
elif [ "${ACTION}" = "build-mini" ]
then
	make clean V=1
	make prepare-mini V=1 RELEASE=${RELEASE} ROOTHACK=1 BASE=${BASE}
	cd mini
	make clean V=1
	make iso V=1 RELEASE=${RELEASE} ROOTHACK=1 BASE=${BASE}
	make clean V=1
	cd ..
	make clean V=1
	mv mini/*.iso .
else
	echo "Unknown build step"
	false
fi
