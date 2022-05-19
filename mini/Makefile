# $Id$
#
# mfsBSD-mini
# Copyright (c) 2018 Martin Matuska <mm at FreeBSD.org>
#
# Version 0.2
#

#
# User-defined variables
#
BASEDIR?=${CURDIR}/../work/mfs/rw
BOOTBASE?=${CURDIR}/../work/disk/boot
CDBOOTBASE?=${CURDIR}/../work/cdboot
CFGDIR?=${CURDIR}/conf
MFSROOT_FREE_INODES?=5000
MFSROOT_FREE_BLOCKS?=10%
MFSROOT_MINSIZE?=64m
MFSROOT_MAXSIZE?=64m
ROOTPW_HASH?=$$6$$051DdQA7fTvLymkY$$Z5f6snVFQJKugWmGi8y0motBNaKn9em0y2K0ZsJMku3v9gkiYh8M.OTIIie3RvHpzT6udumtZUtc0kXwJcCMR1
LOCALBASEDIR?=${BASEDIR}

.if defined(LOADER_4TH)
BOOTFILES?=     defaults device.hints loader *.rc *.4th
EFILOADER?=	loader_4th.efi
.else
BOOTFILES?=     defaults device.hints loader lua
EFILOADER?=	loader_lua.efi
.endif

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
#
#
DOFS=${TOOLSDIR}/doFS.sh
BOOTMODULES=acpi ahci
MFSMODULES=geom_mirror geom_nop opensolaris zfs ext2fs smbus ipmi ntfs nullfs tmpfs \
	aesni crypto cryptodev geom_eli
#
.if defined(V)
_v=
VERB=1
.else
_v=@
VERB=
.endif

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
_MODULESDIR=	${BASEDIR}/boot/modules

all: image

destdir: ${_ROOTDIR} ${_BOOTDIR}
${_ROOTDIR}:
	${_v}${MKDIR} ${_ROOTDIR} && ${CHOWN} root:wheel ${_ROOTDIR}

${_BOOTDIR}:
	${_v}${MKDIR} ${_BOOTDIR}/kernel ${_BOOTDIR}/modules && ${CHOWN} -R root:wheel ${_BOOTDIR}

hierarchy: destdir ${WRKDIR}/.hierarchy_done
${WRKDIR}/.hierarchy_done:
	${_v}echo -n "Creating directory hierarchy ..."
	${_v}${MTREE} -deU -f ${BASEDIR}/etc/mtree/BSD.root.dist -p ${_ROOTDIR} > /dev/null
	${_v}${MTREE} -deU -f ${BASEDIR}/etc/mtree/BSD.usr.dist -p ${_ROOTDIR}/usr > /dev/null
	${_v}${TOUCH} ${WRKDIR}/.hierarchy_done
	${_v}echo " done"

installkernel: ${_BOOTDIR} ${WRKDIR}/.installkernel_done
${WRKDIR}/.installkernel_done:
	${_v}echo -n "Installing kernel ..."
	${_v}${CP} -a ${BOOTBASE}/ ${_BOOTDIR}
	${_v}${TOUCH} ${WRKDIR}/.installkernel_done
	${_v}echo " done"

rescuelinks: hierarchy ${WRKDIR}/.rescuelinks_done
${WRKDIR}/.rescuelinks_done:
	${_v}echo -n "Installing rescue with linking script ..."
	${_v}${INSTALL} -m 0555 ${BASEDIR}/rescue/rescue ${_ROOTDIR}/rescue/rescue
	${_v}for FILE in `cat ${FILESDIR}/rescuelinks`; do \
		${LN} ${_ROOTDIR}/rescue/rescue ${_ROOTDIR}/$${FILE}; \
	done
	${_v}${TOUCH} ${WRKDIR}/.rescuelinks_done
	${_v}echo " done"

installbase: hierarchy rescuelinks ${WRKDIR}/.installbase_done
${WRKDIR}/.installbase_done:
	${_v}echo -n "Installing base files ..."
	${_v}cd ${_ROOTDIR} && for FILE in `cat ${FILESDIR}/instfiles`; do \
		${CP} -pP ${BASEDIR}/$${FILE} ${_ROOTDIR}/$${FILE}; \
	done
	${_v}cd ${_ROOTDIR} && for DIR in `cat ${FILESDIR}/instdirs`; do \
		${CP} -a ${BASEDIR}/$${DIR}/ ${_ROOTDIR}/$${DIR}; \
	done
	${_v}${TOUCH} ${WRKDIR}/.installbase_done
	${_v}echo " done"

basetar: hierarchy rescuelinks ${WRKDIR}/.basetar_done
${WRKDIR}/.basetar_done:
	${_v}echo -n "Creating tar of base libraries and binaries ..."
	${_v}cd ${BASEDIR} && ${TAR} -cJf ${_ROOTDIR}/.mfs_base.txz \
	`cat ${FILESDIR}/basedirs` `cat ${FILESDIR}/basefiles`
	${_v}${TOUCH} ${WRKDIR}/.basetar_done
	${_v}echo " done"

localtar: hierarchy ${WRKDIR}/.localtar_done
${WRKDIR}/.localtar_done:
.if exists(${FILESDIR}/localfiles)
	${_v}echo -n "Creating local files tar ..."
	${_v}cd ${LOCALBASEDIR}/usr/local && ${TAR} -cJf ${_ROOTDIR}/.mfs_local.txz \
	`cat ${FILESDIR}/localfiles`
	${_v}${TOUCH} ${WRKDIR}/.localtar_done
	${_v}echo " done"
.endif
	
install: installbase basetar localtar

config: install ${WRKDIR}/.config_done
${WRKDIR}/.config_done:
	${_v}echo -n "Installing configuration scripts and files ..."
	${_v}if [ -f "${CFGDIR}/loader.conf" ]; then \
		${INSTALL} -m 0644 ${CFGDIR}/loader.conf ${_BOOTDIR}/loader.conf; \
	else \
		${INSTALL} -m 0644 ${CFGDIR}/loader.conf.sample ${_BOOTDIR}/loader.conf; \
	fi
.for FILE in rc hosts ttys resolv.conf rc.local
	${_v}if [ -f "${CFGDIR}/${FILE}" ]; then \
		${INSTALL} -m 0644 ${CFGDIR}/${FILE} ${_ROOTDIR}/etc/${FILE}; \
	elif [ -f "${CFGDIR}/${FILE}.sample" ]; then \
		${INSTALL} -m 0644 ${CFGDIR}/${FILE}.sample ${_ROOTDIR}/etc/${FILE}; \
	fi
.endfor
	${_v}${MKDIR} ${_ROOTDIR}/root/bin
.for FILE in .cshrc .profile
	${_v}if [ -f "${CFGDIR}/${FILE}" ]; then \
		${INSTALL} -m 0644 ${CFGDIR}/${FILE} ${_ROOTDIR}/root/${FILE}; \
	elif [ -f "${CFGDIR}/${FILE}.sample" ]; then \
		${INSTALL} -m 0644 ${CFGDIR}/${FILE}.sample ${_ROOTDIR}/root/${FILE}; \
	fi
.endfor
	${_v}${INSTALL} ${TOOLSDIR}/zfsinstall ${_ROOTDIR}/root/bin
	${_v}${INSTALL} ${TOOLSDIR}/destroygeom ${_ROOTDIR}/root/bin
	${_v}echo "/dev/md0 / ufs rw 0 0" > ${_ROOTDIR}/etc/fstab
	${_v}echo "tmpfs /tmp tmpfs rw,mode=1777 0 0" >> ${_ROOTDIR}/etc/fstab
.if defined(ROOTPW)
	${_v}echo '${ROOTPW}'| ${OPENSSL} passwd -6 -stdin | ${PW} -V ${_ROOTDIR}/etc usermod root -H 0
.elif !empty(ROOTPW_HASH)
	${_v}echo '${ROOTPW_HASH}'| ${PW} -V ${_ROOTDIR}/etc usermod root -H 0
.endif
	${_v}${TOUCH} ${WRKDIR}/.config_done
	${_v}echo " done"

boot: installkernel install ${WRKDIR}/.boot_done
${WRKDIR}/.boot_done:
	${_v}echo -n "Configuring boot environment ..."
	${_v}${MKDIR} ${WRKDIR}/disk/boot && ${CHOWN} root:wheel ${WRKDIR}/disk
	${_v}${RM} -f ${_BOOTDIR}/kernel/kernel.debug
	${_v}${CP} -rp ${_BOOTDIR}/kernel ${WRKDIR}/disk/boot
.for FILE in ${BOOTFILES}
	${_v}${CP} -rp ${_ROOTDIR}/boot/${FILE} ${WRKDIR}/disk/boot
.endfor
	${_v}${RM} -rf ${WRKDIR}/disk/boot/kernel/*.ko ${WRKDIR}/disk/boot/kernel/*.symbols
.if defined(DEBUG)
	${_v}test -f ${_BOOTDIR}/kernel/kernel.symbols \
	&& ${INSTALL} -m 0555 ${_BOOTDIR}/kernel/kernel.symbols ${WRKDIR}/disk/boot/kernel >/dev/null 2>/dev/null || exit 0
.endif
.for FILE in ${BOOTMODULES}
	${_v}test -f ${_BOOTDIR}/kernel/${FILE}.ko \
	&& ${INSTALL} -m 0555 ${_BOOTDIR}/kernel/${FILE}.ko ${WRKDIR}/disk/boot/kernel >/dev/null 2>/dev/null || exit 0
. if defined(DEBUG)
	${_v}test -f ${_BOOTDIR}/kernel/${FILE}.ko \
	&& ${INSTALL} -m 0555 ${_BOOTDIR}/kernel/${FILE}.ko.symbols ${WRKDIR}/disk/boot/kernel >/dev/null 2>/dev/null || exit 0
. endif
.endfor
	${_v}${MKDIR} ${_ROOTDIR}/boot/modules
.for FILE in ${MFSMODULES}
	${_v}test -f ${_MODULESDIR}/${FILE}.ko \
	&& ${INSTALL} -m 0555 ${_MODULESDIR}/${FILE}.ko ${_ROOTDIR}/boot/modules >/dev/null 2>/dev/null || exit 0
. if defined(DEBUG)
	${_v}test -f ${_MODULESDIR}/${FILE}.ko.symbols \
	&& ${INSTALL} -m 0555 ${_MODULESDIR}/${FILE}.ko.symbols ${_ROOTDIR}/boot/modules >/dev/null 2>/dev/null || exit 0
. endif
.endfor
	${_v}${RM} -rf ${_BOOTDIR}/kernel ${_BOOTDIR}/*.symbols
	${_v}${TOUCH} ${WRKDIR}/.boot_done
	${_v}echo " done"

efiboot: boot ${WRKDIR}/.efiboot_done
${WRKDIR}/.efiboot_done:
.if !defined(NO_EFIBOOT)
	@echo -n "Creating EFI boot image ..."
	${_v}${MKDIR} -p ${WRKDIR}/efiroot/EFI/BOOT ${WRKDIR}/cdboot
	${_v}${CP} ${CDBOOTBASE}/${EFILOADER} ${WRKDIR}/efiroot/EFI/BOOT/BOOTX64.efi
	${_v}${MAKEFS} -t msdos -s 2048k -o fat_type=12,sectors_per_cluster=1 ${WRKDIR}/cdboot/efiboot.img ${WRKDIR}/efiroot
	${_v}${TOUCH} ${WRKDIR}/.efiboot_done
	@echo " done"
.endif

boottar: boot ${WRKDIR}/.boottar_done
${WRKDIR}/.boottar_done:
	${_v}echo -n "Compressing mfsroot boot ..."
	${_v}${TAR} -c -J -C ${_ROOTDIR} -f ${_ROOTDIR}/.mfs_boot.txz boot
	${_v}cd ${_ROOTDIR} && ${RM} -rf boot
	${_v}${TOUCH} ${WRKDIR}/.boottar_done
	${_v}echo " done"

mfsroot: boottar ${WRKDIR}/.mfsroot_done
${WRKDIR}/.mfsroot_done:
	${_v}echo -n "Creating and compressing mfsroot ..."
	${_v}${MKDIR} ${WRKDIR}/mnt
	${_v}${MAKEFS} -t ffs -M ${MFSROOT_MINSIZE} -m ${MFSROOT_MAXSIZE} -f ${MFSROOT_FREE_INODES} -b ${MFSROOT_FREE_BLOCKS} ${WRKDIR}/disk/mfsroot ${_ROOTDIR} > /dev/null
	${_v}${RM} -rf ${WRKDIR}/mnt
	${_v}${GZIP} -9 -f ${WRKDIR}/disk/mfsroot
	${_v}${GZIP} -9 -f ${WRKDIR}/disk/boot/kernel/kernel
	${_v}if [ -f "${CFGDIR}/loader.conf" ]; then \
		${INSTALL} -m 0644 ${CFGDIR}/loader.conf ${WRKDIR}/disk/boot/loader.conf; \
	else \
		${INSTALL} -m 0644 ${CFGDIR}/loader.conf.sample ${WRKDIR}/disk/boot/loader.conf; \
	fi
	${_v}${TOUCH} ${WRKDIR}/.mfsroot_done
	${_v}echo " done"

image: install config boot mfsroot ${IMAGE}
${IMAGE}:
	@echo -n "Creating image file ..."
.if defined(BSDPART)
	${_v}${MKDIR} ${WRKDIR}/mnt ${WRKDIR}/trees/base/boot
	${_v}${INSTALL} -m 0444 ${WRKDIR}/disk/boot/boot ${WRKDIR}/trees/base/boot/
	${_v}${DOFS} ${BSDLABEL} "" ${WRKDIR}/disk.img ${WRKDIR} ${WRKDIR}/mnt 0 ${WRKDIR}/disk 80000 auto > /dev/null 2> /dev/null
	${_v}${RM} -rf ${WRKDIR}/mnt ${WRKDIR}/trees
	${_v}${MV} ${WRKDIR}/disk.img ${.TARGET}
.else
	${_v}${TOOLSDIR}/do_gpt.sh ${.TARGET} ${WRKDIR}/disk 0 ${BASEDIR}/boot ${WRKDIR}/cdboot/efiboot.img ${VERB}
.endif
	@echo " done"
	${_v}${LS} -l ${.TARGET}

gce: install config boot mfsroot ${IMAGE} ${GCEFILE}
${GCEFILE}:
	${_v}echo -n "Creating GCE-compatible tarball..."
.if !exists(${GTAR})
	${_v}echo "${GTAR} is missing, please install archivers/gtar first"; exit 1
.else
	${_v}${GTAR} -C ${CURDIR} -Szcf ${GCEFILE} --transform='s/${IMAGE}/disk.raw/' ${IMAGE}
	${_v}echo " GCE tarball built"
	${_v}${LS} -l ${GCEFILE}
.endif

iso: install config boot efiboot mfsroot ${ISOIMAGE}
${ISOIMAGE}:
	${_v}echo -n "Creating ISO image ..."
.if !defined(NO_EFIBOOT)
	${_v}${MAKEFS} -t cd9660 -o rockridge,label=mfsBSD \
	-o bootimage=i386\;${CDBOOTBASE}/cdboot,no-emul-boot \
	-o bootimage=i386\;${WRKDIR}/cdboot/efiboot.img,no-emul-boot,platformid=efi \
	${ISOIMAGE} ${WRKDIR}/disk
.else
	${_v}${MAKEFS} -t cd9660 -o rockridge,label=mfsBSD \
	-o bootimage=i386\;${CDBOOTBASE}/cdboot,no-emul-boot \
	${ISOIMAGE} ${WRKDIR}/disk
.endif
	${_v}echo " done"
	${_v}${LS} -l ${ISOIMAGE}

tar: install config boot mfsroot ${TARFILE}
${TARFILE}:
	${_v}echo -n "Creating tar file ..."
	${_v}cd ${WRKDIR}/disk && ${FIND} . -depth 1 \
		-exec ${TAR} -r -f ${CURDIR}/${TARFILE} {} \;
	${_v}echo " done"
	${_v}${LS} -l ${TARFILE}

clean: 
	${_v}if [ -d ${WRKDIR} ]; then \
	${CHFLAGS} -R noschg ${WRKDIR} && \
	cd ${WRKDIR} && ${RM} -rf mfs mnt disk dist trees efiroot cdboot .*_done; \
	fi
