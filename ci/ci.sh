#!/bin/sh
set -e
BASE=/tmp/freebsd-dist
RELEASE=${RELEASE:-12.1-RELEASE}
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
	fetch -o ${BASE}/base.txz ${DOWNLOAD_URL}/base.txz
	fetch -o ${BASE}/kernel.txz ${DOWNLOAD_URL}/kernel.txz
elif [ "${ACTION}" = "build-std" ]
then
	make clean
	make iso RELEASE=${RELEASE} BASE=${BASE}
	make RELEASE=${RELEASE} BASE=${BASE}
elif [ "${ACTION}" = "build-se" ]
then
	make clean
	make iso RELEASE=${RELEASE} BASE=${BASE} SE=1
	make RELEASE=${RELEASE} BASE=${BASE} SE=1
elif [ "${ACTION}" = "build-mini" ]
then
	make clean
	make prepare-mini
	cd mini && make clean && make iso RELEASE=${RELEASE} && make clean && cd ..
	make clean
	mv mini/*.iso .
else
	echo "Unknown build step"
	false
fi
