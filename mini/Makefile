# $Id$
#
# mfsBSD-mini
# Copyright (c) 2014 Martin Matuska <mm at FreeBSD.org>
#
# Version 0.1
#

#
# User-defined variables
#
BASEDIR?=${CURDIR}/../tmp/mfs
MFSROOT_FREE_INODES?=5000
MFSROOT_FREE_BLOCKS?=10%
MFSROOT_MINSIZE?=64m
MFSROOT_MAXSIZE?=64m
ROOTPW?=mfsroot
LOCALBASEDIR?=/

#
# Program defaults
#
CAT=/bin/cat
CHFLAGS=/bin/chflags
CHOWN=/usr/sbin/chown
CP=/bin/cp
DIRNAME=/usr/bin/dirname
FIND=/usr/bin/find
GTAR=/usr/local/bin/gtar
GZIP=/usr/bin/gzip
INSTALL=/usr/bin/install
LN=/bin/ln
LS=/bin/ls
MAKEFS=/usr/sbin/makefs
MKDIR=/bin/mkdir -p
MTREE=/usr/sbin/mtree
MV=/bin/mv
PW=/usr/sbin/pw
PWD=/bin/pwd
RM=/bin/rm
RMDIR=/bin/rmdir
SYSCTL=/sbin/sysctl
TAR=/usr/bin/tar
TOUCH=/usr/bin/touch
UNAME=/usr/bin/uname
#
BSDLABEL=bsdlabel

#
CURDIR!=${PWD}
WRKDIR?=${CURDIR}/tmp
FILESDIR=${CURDIR}/files
TOOLSDIR=${CURDIR}/../tools
CFGDIR=${CURDIR}/conf
#
#
DOFS=${TOOLSDIR}/doFS.sh
BOOTMODULES=acpi ahci
MFSMODULES=geom_mirror geom_nop opensolaris zfs ext2fs smbus ipmi ntfs nullfs tmpfs \
	crypto cryptodev geom_eli
#

.if !defined(ARCH)
TARGET!=	${SYSCTL} -n hw.machine_arch
.else
TARGET=		${ARCH} 
.endif

.if !defined(RELEASE)
RELEASE!=${UNAME} -r
.endif

IMAGE_PREFIX=mfsbsd-mini

IMAGE?=	${IMAGE_PREFIX}-${RELEASE}-${TARGET}.img
ISOIMAGE?= ${IMAGE_PREFIX}-${RELEASE}-${TARGET}.iso
TARFILE?= ${IMAGE_PREFIX}-${RELEASE}-${TARGET}.tar
GCEFILE?= ${IMAGE_PREFIX}-${RELEASE}-${TARGET}.tar.gz
_DISTDIR= ${WRKDIR}/dist/${RELEASE}-${TARGET}

.if !defined(DEBUG)
EXCLUDE=--exclude *.symbols
.else
EXCLUDE=
.endif

_ROOTDIR=	${WRKDIR}/mfs
_BOOTDIR=	${_ROOTDIR}/boot

all: image

destdir: ${_ROOTDIR} ${_BOOTDIR}
${_ROOTDIR}:
	@${MKDIR} ${_ROOTDIR} && ${CHOWN} root:wheel ${_ROOTDIR}

${_BOOTDIR}:
	@${MKDIR} ${_BOOTDIR}/kernel ${_BOOTDIR}/modules && ${CHOWN} -R root:wheel ${_BOOTDIR}

hierarchy: destdir ${WRKDIR}/.hierarchy_done
${WRKDIR}/.hierarchy_done:
	@echo -n "Creating directory hierarchy ..."
	@${MTREE} -deU -f ${BASEDIR}/etc/mtree/BSD.root.dist -p ${_ROOTDIR} > /dev/null
	@${MTREE} -deU -f ${BASEDIR}/etc/mtree/BSD.usr.dist -p ${_ROOTDIR}/usr > /dev/null
	@${TOUCH} ${WRKDIR}/.hierarchy_done
	@echo " done"

installkernel: ${_BOOTDIR} ${WRKDIR}/.installkernel_done
${WRKDIR}/.installkernel_done:
	@echo -n "Installing kernel ..."
	@${CP} -a ${BASEDIR}/boot/ ${_BOOTDIR}
	@${TOUCH} ${WRKDIR}/.installkernel_done
	@echo " done"

rescuelinks: hierarchy ${WRKDIR}/.rescuelinks_done
${WRKDIR}/.rescuelinks_done:
	@echo -n "Installing rescue with linking script ..."
	@${INSTALL} -m 0555 ${BASEDIR}/rescue/rescue ${_ROOTDIR}/rescue/rescue
	@for FILE in `cat ${FILESDIR}/rescuelinks`; do \
		${LN} ${_ROOTDIR}/rescue/rescue ${_ROOTDIR}/$${FILE}; \
	done
	@${TOUCH} ${WRKDIR}/.rescuelinks_done
	@echo " done"

installbase: hierarchy rescuelinks ${WRKDIR}/.installbase_done
${WRKDIR}/.installbase_done:
	@echo -n "Installing base files ..."
	@cd ${_ROOTDIR} && for FILE in `cat ${FILESDIR}/instfiles`; do \
		${CP} -pP ${BASEDIR}/$${FILE} ${_ROOTDIR}/$${FILE}; \
	done
	@cd ${_ROOTDIR} && for DIR in `cat ${FILESDIR}/instdirs`; do \
		${CP} -a ${BASEDIR}/$${DIR}/ ${_ROOTDIR}/$${DIR}; \
	done
	@${TOUCH} ${WRKDIR}/.installbase_done
	@echo " done"

basetar: hierarchy rescuelinks ${WRKDIR}/.basetar_done
${WRKDIR}/.basetar_done:
	@echo -n "Creating tar of base libraries and binaries ..."
	@cd ${BASEDIR} && ${TAR} -cJf ${_ROOTDIR}/.mfs_base.txz \
	`cat ${FILESDIR}/basedirs` `cat ${FILESDIR}/basefiles`
	@${TOUCH} ${WRKDIR}/.basetar_done
	@echo " done"

localtar: hierarchy ${WRKDIR}/.localtar_done
${WRKDIR}/.localtar_done:
.if exists(${FILESDIR}/localfiles)
	@echo -n "Creating local files tar ..."
	@cd ${LOCALBASEDIR}/usr/local && ${TAR} -cJf ${_ROOTDIR}/.mfs_local.txz \
	`cat ${FILESDIR}/localfiles`
	@${TOUCH} ${WRKDIR}/.localtar_done
	@echo " done"
.endif
	
install: installbase basetar localtar

config: install ${WRKDIR}/.config_done
${WRKDIR}/.config_done:
	@echo -n "Installing configuration scripts and files ..."
	@if [ -f "${CFGDIR}/loader.conf" ]; then \
		${INSTALL} -m 0644 ${CFGDIR}/loader.conf ${_BOOTDIR}/loader.conf; \
	else \
		${INSTALL} -m 0644 ${CFGDIR}/loader.conf.sample ${_BOOTDIR}/loader.conf; \
	fi
.for FILE in rc hosts ttys resolv.conf rc.local
	@if [ -f "${CFGDIR}/${FILE}" ]; then \
		${INSTALL} -m 0644 ${CFGDIR}/${FILE} ${_ROOTDIR}/etc/${FILE}; \
	elif [ -f "${CFGDIR}/${FILE}.sample" ]; then \
		${INSTALL} -m 0644 ${CFGDIR}/${FILE}.sample ${_ROOTDIR}/etc/${FILE}; \
	fi
.endfor
	@${MKDIR} ${_ROOTDIR}/root/bin
.for FILE in .cshrc .profile
	@if [ -f "${CFGDIR}/${FILE}" ]; then \
		${INSTALL} -m 0644 ${CFGDIR}/${FILE} ${_ROOTDIR}/root/${FILE}; \
	elif [ -f "${CFGDIR}/${FILE}.sample" ]; then \
		${INSTALL} -m 0644 ${CFGDIR}/${FILE}.sample ${_ROOTDIR}/root/${FILE}; \
	fi
.endfor
	@${INSTALL} ${TOOLSDIR}/zfsinstall ${_ROOTDIR}/root/bin
	@${INSTALL} ${TOOLSDIR}/destroygeom ${_ROOTDIR}/root/bin
	@echo "/dev/md0 / ufs rw 0 0" > ${_ROOTDIR}/etc/fstab
	@echo "tmpfs /tmp tmpfs rw,mode=1777 0 0" >> ${_ROOTDIR}/etc/fstab
	@echo ${ROOTPW} | ${PW} -V ${_ROOTDIR}/etc usermod root -h 0
	@${TOUCH} ${WRKDIR}/.config_done
	@echo " done"


boot: installkernel install ${WRKDIR}/.boot_done
${WRKDIR}/.boot_done:
	@echo -n "Configuring boot environment ..."
	@${MKDIR} ${WRKDIR}/disk/boot && ${CHOWN} root:wheel ${WRKDIR}/disk
	@${RM} -f ${_BOOTDIR}/kernel/kernel.debug
	@${CP} -rp ${_BOOTDIR}/kernel ${WRKDIR}/disk/boot
.for FILE in boot defaults loader loader.help *.rc *.4th
	@${CP} -rp ${_ROOTDIR}/boot/${FILE} ${WRKDIR}/disk/boot
.endfor
	@${RM} -rf ${WRKDIR}/disk/boot/kernel/*.ko ${WRKDIR}/disk/boot/kernel/*.symbols
.if defined(DEBUG)
	@test -f ${_BOOTDIR}/kernel/kernel.symbols \
	&& ${INSTALL} -m 0555 ${_BOOTDIR}/kernel/kernel.symbols ${WRKDIR}/disk/boot/kernel >/dev/null 2>/dev/null || exit 0
.endif
.for FILE in ${BOOTMODULES}
	@test -f ${_BOOTDIR}/kernel/${FILE}.ko \
	&& ${INSTALL} -m 0555 ${_BOOTDIR}/kernel/${FILE}.ko ${WRKDIR}/disk/boot/kernel >/dev/null 2>/dev/null || exit 0
. if defined(DEBUG)
	@test -f ${_BOOTDIR}/kernel/${FILE}.ko \
	&& ${INSTALL} -m 0555 ${_BOOTDIR}/kernel/${FILE}.ko.symbols ${WRKDIR}/disk/boot/kernel >/dev/null 2>/dev/null || exit 0
. endif
.endfor
	@${MKDIR} ${_ROOTDIR}/boot/modules
.for FILE in ${MFSMODULES}
	@test -f ${_BOOTDIR}/kernel/${FILE}.ko \
	&& ${INSTALL} -m 0555 ${_BOOTDIR}/kernel/${FILE}.ko ${_ROOTDIR}/boot/modules >/dev/null 2>/dev/null || exit 0
. if defined(DEBUG)
	@test -f ${_BOOTDIR}/kernel/${FILE}.ko.symbols \
	&& ${INSTALL} -m 0555 ${_BOOTDIR}/kernel/${FILE}.ko.symbols ${_ROOTDIR}/boot/modules >/dev/null 2>/dev/null || exit 0
. endif
.endfor
	@${RM} -rf ${_BOOTDIR}/kernel ${_BOOTDIR}/*.symbols
	@${TOUCH} ${WRKDIR}/.boot_done
	@echo " done"

boottar: boot ${WRKDIR}/.boottar_done
${WRKDIR}/.boottar_done:
	@echo -n "Compressing mfsroot boot ..."
	@${TAR} -c -J -C ${_ROOTDIR} -f ${_ROOTDIR}/.mfs_boot.txz boot
	@cd ${_ROOTDIR} && ${RM} -rf boot
	@${TOUCH} ${WRKDIR}/.boottar_done
	@echo " done"

mfsroot: boottar ${WRKDIR}/.mfsroot_done
${WRKDIR}/.mfsroot_done:
	@echo -n "Creating and compressing mfsroot ..."
	@${MKDIR} ${WRKDIR}/mnt
	@${MAKEFS} -t ffs -M ${MFSROOT_MINSIZE} -m ${MFSROOT_MAXSIZE} -f ${MFSROOT_FREE_INODES} -b ${MFSROOT_FREE_BLOCKS} ${WRKDIR}/disk/mfsroot ${_ROOTDIR} > /dev/null
	@${RM} -rf ${WRKDIR}/mnt
	@${GZIP} -9 -f ${WRKDIR}/disk/mfsroot
	@${GZIP} -9 -f ${WRKDIR}/disk/boot/kernel/kernel
	@if [ -f "${CFGDIR}/loader.conf" ]; then \
		${INSTALL} -m 0644 ${CFGDIR}/loader.conf ${WRKDIR}/disk/boot/loader.conf; \
	else \
		${INSTALL} -m 0644 ${CFGDIR}/loader.conf.sample ${WRKDIR}/disk/boot/loader.conf; \
	fi
	@${TOUCH} ${WRKDIR}/.mfsroot_done
	@echo " done"

image: install config boot mfsroot ${IMAGE}
${IMAGE}:
	@echo -n "Creating image file ..."
	@${MKDIR} ${WRKDIR}/mnt ${WRKDIR}/trees/base/boot
	@${INSTALL} -m 0444 ${WRKDIR}/disk/boot/boot ${WRKDIR}/trees/base/boot/
	@${DOFS} ${BSDLABEL} "" ${WRKDIR}/disk.img ${WRKDIR} ${WRKDIR}/mnt 0 ${WRKDIR}/disk 80000 auto > /dev/null 2> /dev/null
	@${RM} -rf ${WRKDIR}/mnt ${WRKDIR}/trees
	@${MV} ${WRKDIR}/disk.img ${IMAGE}
	@echo " done"
	@${LS} -l ${IMAGE}

gce: install config boot mfsroot ${IMAGE} ${GCEFILE}
${GCEFILE}:
	@echo -n "Creating GCE-compatible tarball..."
.if !exists(${GTAR})
	@echo "${GTAR} is missing, please install archivers/gtar first"; exit 1
.else
	@${GTAR} -C ${CURDIR} -Szcf ${GCEFILE} --transform='s/${IMAGE}/disk.raw/' ${IMAGE}
	@echo " GCE tarball built"
	@${LS} -l ${GCEFILE}
.endif

iso: install config boot mfsroot ${ISOIMAGE}
${ISOIMAGE}:
	@echo -n "Creating ISO image ..."
	@${MAKEFS} -t cd9660 -o rockridge,bootimage=i386\;/boot/cdboot,no-emul-boot,label=mfsBSD ${ISOIMAGE} ${WRKDIR}/disk
	@echo " done"
	@${LS} -l ${ISOIMAGE}

tar: install config boot mfsroot ${TARFILE}
${TARFILE}:
	@echo -n "Creating tar file ..."
	@cd ${WRKDIR}/disk && ${FIND} . -depth 1 \
		-exec ${TAR} -r -f ${CURDIR}/${TARFILE} {} \;
	@echo " done"
	@${LS} -l ${TARFILE}

clean: 
	@if [ -d ${WRKDIR} ]; then ${CHFLAGS} -R noschg ${WRKDIR}; fi
	@cd ${WRKDIR} && ${RM} -rf mfs mnt disk dist trees .*_done
