#!/bin/sh

set -e

vmake()
{
	env TARGET=${TARGET} \
	    TARGET_ARCH=${TARGET_ARCH} \
	    V=1 \
	    make "$@"
}

BASE="${TMPDIR:-/tmp}/freebsd-dist"

# Chop the patch off the release for the running host, e.g.,
# '14.3-RELEASE-p7' -> '14.3-RELEASE'.
#
: "${RELEASE=$(uname -r | sed -Ee 's/-p[[:digit:]]$//')}"
: "${TARGET=$(uname -m)}"
: "${TARGET_ARCH=$(uname -p)}"
DOWNLOAD_URL=http://ftp.freebsd.org/pub/FreeBSD/releases/${TARGET}/${RELEASE}

while getopts b:r: opt
do
	case $opt in
		b) ACTION="${OPTARG}";;
		r) RELEASE="${OPTARG}";;
	esac
done

case "${ACTION}" in
prepare)
	mkdir -p ${BASE}
	fetch -m -o ${BASE}/base.txz ${DOWNLOAD_URL}/base.txz
	fetch -m -o ${BASE}/kernel.txz ${DOWNLOAD_URL}/kernel.txz
	if [ ! -x tools/roothack/roothack ]
	then
		cd tools/roothack && make depend && make
	fi
	;;
build-std)
	vmake clean
	vmake iso RELEASE=${RELEASE} BASE=${BASE} ROOTHACK=1
	vmake RELEASE=${RELEASE} BASE=${BASE} ROOTHACK=1
	;;
build-se)
	vmake clean
	vmake iso RELEASE=${RELEASE} BASE=${BASE} ROOTHACK=1 SE=1
	vmake RELEASE=${RELEASE} BASE=${BASE} ROOTHACK=1 SE=1
	;;
build-mini)
	vmake clean
	vmake prepare-mini RELEASE=${RELEASE} ROOTHACK=1 BASE=${BASE}
	(
		cd mini
		vmake clean
		vmake iso RELEASE=${RELEASE} ROOTHACK=1 BASE=${BASE}
		vmake clean
	)
	vmake clean
	mv mini/*.iso .
	;;
*)
	echo "Unknown build step"
	false
	;;
esac
