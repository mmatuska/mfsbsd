# $Id$
#
# mfsBSD-mini
# Copyright (c) 2021 Martin Matuska <mm at FreeBSD.org>
#
# Version 0.3
#

# The primary targets in this file are:
#
# clean 	Clean up
# all		Create raw image file
# image 	Create raw image file
# iso		Create a bootable ISO image
# tar		Create tar.gz file with kernal and mfsroot
# gce		Create GCE-compatible .tar.gz file
#
# If you want to build mfsBSD-mini:
# cd ..
# make prepare-mini -DV
# cd mini
# make image -DV
# make iso

#
# Paths and user-defined variables
#
BASEDIR?=		${CURDIR}/../work/mfs
BOOTBASE?=		${CURDIR}/../work/disk/boot
CFGDIR?=		${CURDIR}/conf
WRKDIR?=		${CURDIR}/tmp
FILESDIR=		${CURDIR}/files
TOOLSDIR=		${CURDIR}/../tools
CURDIR=                 ${PWD}
#
MFSROOT_FREE_INODES?=	5000
MFSROOT_FREE_BLOCKS?=	10%
MFSROOT_MINSIZE?=	64m
MFSROOT_MAXSIZE?=	64m
ROOTPW_HASH?=		$$6$$051DdQA7fTvLymkY$$Z5f6snVFQJKugWmGi8y0motBNaKn9em0y2K0ZsJMku3v9gkiYh8M.OTIIie3RvHpzT6udumtZUtc0kXwJcCMR1
LOCALBASEDIR?=		${BASEDIR}

.if defined(LOADER_4TH)
BOOTFILES?=     defaults device.hints loader *.rc *.4th
.else
BOOTFILES?=     defaults device.hints loader lua
.endif

#
# Program defaults
#
CAT?=		/bin/cat
CHFLAGS?=	/bin/chflags
CHOWN?= 	/usr/sbin/chown
CP?=		/bin/cp
DIRNAME?=	/usr/bin/dirname
FIND?=		/usr/bin/find
GTAR?=		/usr/local/bin/gtar
GZIP?=		/usr/bin/gzip
INSTALL?=	/usr/bin/install
LN?=		/bin/ln
LS?=		/bin/ls
MAKEFS?=	/usr/sbin/makefs
MKDIR?= 	/bin/mkdir
MTREE?= 	/usr/sbin/mtree
MV?=		/bin/mv
OPENSSL?=	/usr/bin/openssl
PW?=		/usr/sbin/pw
PWD?=		/bin/pwd
RM?=		/bin/rm
RMDIR?= 	/bin/rmdir
SYSCTL?=	/sbin/sysctl
TAR?=		/usr/bin/tar
TOUCH?= 	/usr/bin/touch
UNAME?= 	/usr/bin/uname
#
BSDLABEL?=      bsdlabel
#
DOFS=		${TOOLSDIR}/doFS.sh
DO_GPT?=	${TOOLSDIR}/do_gpt.sh
SCRIPTS?=
BOOTMODULES=acpi ahci
.if defined(LOADER_4TH)
BOOTFILES?=     defaults device.hints loader *.rc *.4th
.else
BOOTFILES?=     defaults device.hints loader lua
.endif
MFSMODULES=geom_mirror geom_nop opensolaris zfs ext2fs smbus ipmi ntfs \
	nullfs tmpfs aesni crypto cryptodev geom_eli
# Sometimes the kernel is compiled with a different destination.
KERNDIR?=       kernel
#
XZ_FLAGS?=
#

VERBOSE=
.if defined(V)
_v=
VERB=1
VERBOSE=	--verbose
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

IMAGE?= 	${IMAGE_PREFIX}-${RELEASE}-${TARGET}.img
ISOIMAGE?=	${IMAGE_PREFIX}-${RELEASE}-${TARGET}.iso
TARFILE?=	${IMAGE_PREFIX}-${RELEASE}-${TARGET}.tar
GCEFILE?=	${IMAGE_PREFIX}-${RELEASE}-${TARGET}.tar.gz
_DISTDIR=	${WRKDIR}/dist/${RELEASE}-${TARGET}

SALT?=		`${OPENSSL} rand -base64 16`

.if !defined(DEBUG)
EXCLUDE=--exclude *.symbols
.else
EXCLUDE=
.endif

_ROOTDIR=	${WRKDIR}/mfs
_BOOTDIR=	${_ROOTDIR}/boot
_MODULESDIR=	${BASEDIR}/boot/modules

.PHONY: destdir checkfiles hierarchy installkernel rescuelinks installbase \
basetar localtar install config boot boottar mfsroot \
image iso tar gce all clean

all: image

checkfiles: ${WRKDIR}/.checkfiles_done
${WRKDIR}/.checkfiles_done:
	@echo "---------------------------------------------------- $(@F)"
	@echo "Check directories and files in ${BASEDIR} ..."
	${_v}cd ${BASEDIR}
	${_v}-( RET=0 ; \
	for LIST in `ls ${FILESDIR}`; do \
		echo "Check from ${FILESDIR}/$${LIST}"; \
		for FILE in `cat ${CURDIR}/files/$${LIST}`; do \
			if [ ! -d "${BASEDIR}/$${FILE}" ]; then \
				if [ ! -f "${BASEDIR}/$${FILE}" ]; then \
					${LS} ${BASEDIR}/$${FILE} > /dev/null; \
					RETLS=$$?; \
					if [ $${RETLS} -ne 0 ]; then \
						RET=$${RETLS}; \
					fi; \
				fi; \
			fi; \
		done ; \
	done; \
	if [ $${RET} -ne 0 ]; then exit 1; fi; ) && \
	([ $$? -eq 0 ] && echo "SUCCESS!" > .pass ) || \
	(echo "FAILURE!" > .pass )
	${_v}if [ `cat .pass` == "SUCCESS!" ]; then \
		${RM} .pass ; \
		${TOUCH} ${WRKDIR}/.checkfiles_done; \
		echo " done"; \
	else \
		${RM} .pass ; \
		echo " failure"; exit 1; \
	fi

destdir: checkfiles ${WRKDIR}/.destdir_done
${WRKDIR}/.destdir_done:
	@echo "---------------------------------------------------- $(@F)"
	@echo "Make directory - ${_ROOTDIR}"
	${_v}${MKDIR} -p ${_ROOTDIR} && ${CHOWN} root:wheel ${_ROOTDIR}
	@echo "Make directory - ${_BOOTDIR}"
	${_v}${MKDIR} -p ${_BOOTDIR}/kernel ${_BOOTDIR}/modules && \
		${CHOWN} -R root:wheel ${_BOOTDIR}
	${_v}${TOUCH} ${WRKDIR}/.destdir_done
	@echo " done"

hierarchy: destdir ${WRKDIR}/.hierarchy_done
${WRKDIR}/.hierarchy_done:
	@echo "---------------------------------------------------- $(@F)"
	@echo "Creating directory hierarchy ..."
	${_v}${MTREE} -deU -f ${BASEDIR}/etc/mtree/BSD.root.dist -p ${_ROOTDIR} > /dev/null
	${_v}${MTREE} -deU -f ${BASEDIR}/etc/mtree/BSD.usr.dist -p ${_ROOTDIR}/usr > /dev/null
	${_v}${TOUCH} ${WRKDIR}/.hierarchy_done
	@echo " done"

installkernel: hierarchy ${WRKDIR}/.installkernel_done
${WRKDIR}/.installkernel_done:
	@echo "---------------------------------------------------- $(@F)"
	@echo "Installing kernel ..."
	${_v}${CP} -a ${BOOTBASE}/ ${_BOOTDIR}
	${_v}${TOUCH} ${WRKDIR}/.installkernel_done
	@echo " done"

rescuelinks: hierarchy ${WRKDIR}/.rescuelinks_done
${WRKDIR}/.rescuelinks_done:
	@echo "---------------------------------------------------- $(@F)"
	@echo "Installing rescue with linking script ..."
	${_v}${INSTALL} -m 0555 ${BASEDIR}/rescue/rescue ${_ROOTDIR}/rescue/rescue
	${_v}for FILE in `cat ${FILESDIR}/rescuelinks`; do \
		${LN} ${_ROOTDIR}/rescue/rescue ${_ROOTDIR}/$${FILE}; \
	done
	${_v}${TOUCH} ${WRKDIR}/.rescuelinks_done
	@echo " done"

installbase: hierarchy rescuelinks ${WRKDIR}/.installbase_done
${WRKDIR}/.installbase_done:
	@echo "---------------------------------------------------- $(@F)"
	@echo "Installing base files ..."
	${_v}cd ${_ROOTDIR} && for FILE in `cat ${FILESDIR}/instfiles`; do \
		${CP} -pP ${BASEDIR}/$${FILE} ${_ROOTDIR}/$${FILE}; \
	done
	${_v}cd ${_ROOTDIR} && for DIR in `cat ${FILESDIR}/instdirs`; do \
		${CP} -a ${BASEDIR}/$${DIR}/ ${_ROOTDIR}/$${DIR}; \
	done
	${_v}${TOUCH} ${WRKDIR}/.installbase_done
	@echo " done"

basetar: hierarchy rescuelinks ${WRKDIR}/.basetar_done
${WRKDIR}/.basetar_done:
	@echo "---------------------------------------------------- $(@F)"
	@echo "Creating tar of base libraries and binaries ..."
	${_v}cd ${BASEDIR} && \
		for FILE in `cat ${FILESDIR}/basedirs ${FILESDIR}/basefiles`; \
		do \
			echo "$${FILE}" | \
			${TAR} -cJf ${_ROOTDIR}/.mfs_base.txz -T -; \
		done
	${_v}${TOUCH} ${WRKDIR}/.basetar_done
	@echo " done"

localtar: hierarchy ${WRKDIR}/.localtar_done
${WRKDIR}/.localtar_done:
	@echo "---------------------------------------------------- $(@F)"
.if exists(${FILESDIR}/localfiles)
	@echo -n "Creating local files tar ..."
	${_v}cd ${LOCALBASEDIR}/usr/local && \
		for FILE in `cat ${FILESDIR}/localfiles`; \
		do \
			echo "$${FILE}" | \
			${TAR} -cJf ${_ROOTDIR}/.mfs_local.txz -T -; \
		done
	${_v}${TOUCH} ${WRKDIR}/.localtar_done
	${_v}echo " done"
.endif

install: installbase basetar localtar

config: install ${WRKDIR}/.config_done
${WRKDIR}/.config_done:
	@echo "---------------------------------------------------- $(@F)"
	@echo "Installing configuration scripts and files ..."
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
	${_v}${MKDIR} -p ${_ROOTDIR}/root/bin
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
	@echo "Add user accounts ..."
.if defined(ROOTPW)
	${_v}echo '${ROOTPW}'| ${OPENSSL} passwd -6 -stdin -salt ${SALT} | \
		${PW} -V ${_ROOTDIR}/etc usermod root -H 0
.elif !empty(ROOTPW_HASH)
	${_v}echo '${ROOTPW_HASH}'| ${PW} -V ${_ROOTDIR}/etc usermod root -H 0
.endif
	${_v}${TOUCH} ${WRKDIR}/.config_done
	${_v}echo " done"

boot: installkernel install ${WRKDIR}/.boot_done
${WRKDIR}/.boot_done:
	@echo "---------------------------------------------------- $(@F)"
	@echo "Configuring boot environment ..."
	${_v}${MKDIR} -p ${WRKDIR}/disk/boot && \
		${CHOWN} root:wheel ${WRKDIR}/disk
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
	${_v}${MKDIR} -p ${_ROOTDIR}/boot/modules
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

boottar: boot ${WRKDIR}/.boottar_done
${WRKDIR}/.boottar_done:
	@echo "---------------------------------------------------- $(@F)"
	@echo "Compressing mfsroot boot ..."
	${_v}${TAR} -c -J -C ${_ROOTDIR} -f ${_ROOTDIR}/.mfs_boot.txz boot
	${_v}cd ${_ROOTDIR} && ${RM} -rf boot
	${_v}${TOUCH} ${WRKDIR}/.boottar_done
	${_v}echo " done"

mfsroot: boottar ${WRKDIR}/.mfsroot_done
${WRKDIR}/.mfsroot_done:
	@echo "---------------------------------------------------- $(@F)"
	@echo "Creating and compressing mfsroot ..."
	${_v}${MKDIR} -p ${WRKDIR}/mnt
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

image: config boot mfsroot ${WRKDIR}/.image_done
${WRKDIR}/.image_done:
	@echo "---------------------------------------------------- $(@F)"
	@echo "Creating image file - ${IMAGE} ..."
	${_v}if [ -f ${CURDIR}/${IMAGE} ]; then \
	        ${RM} ${CURDIR}/${IMAGE} ; \
	fi
.if defined(BSDPART)
	${_v}${MKDIR} -p ${WRKDIR}/mnt ${WRKDIR}/trees/base/boot
	${_v}${INSTALL} -m 0444 -d -D${WRKDIR}/trees/base/boot ${WRKDIR}/disk/boot
	@echo "\"DOFS DISKLABEL MACHINE FSIMG RD MNT FSSIZE FSPROTO FSINODE FSLABEL\""
	${_v}${DOFS} ${BSDLABEL} "" ${WRKDIR}/disk.img ${WRKDIR} ${WRKDIR}/mnt 0 ${WRKDIR}/disk 80000 auto > /dev/null 2> /dev/null
	${_v}${RM} -rf ${WRKDIR}/mnt ${WRKDIR}/trees
.else
	@echo "\"DO_GPT FSIMG FSPROTO FSSIZE BOOTDIR VERBOSE\""
	${_v}${TOOLSDIR}/do_gpt.sh ${WRKDIR}/disk.img ${WRKDIR}/disk 0 ${BASEDIR}/boot ${VERB}
.endif
	${_v}${MV} ${WRKDIR}/disk.img ${CURDIR}/${IMAGE}
	${_v}${LS} -l ${CURDIR}/${IMAGE}
	${_v}${TOUCH} ${WRKDIR}/.image_done
	@echo " done"

gce: image ${WRKDIR}/.gce_done
${WRKDIR}/.gce_done:
	@echo "---------------------------------------------------- $(@F)"
	@echo "Creating GCE-compatible tarball - ${GCEFILE} ..."
	${_v}if [ -f ${CURDIR}/${GCEFILE} ]; then \
		${RM} ${CURDIR}/${GCEFILE} ; \
	fi
.if !exists(${GTAR})
	${_v}echo "${GTAR} is missing, please install archivers/gtar first"; exit 1
.else
	${_v}${GTAR} -C ${CURDIR} -Szcf ${GCEFILE} --transform='s/${IMAGE}/disk.raw/' ${IMAGE}
	@echo " GCE tarball built"
	${_v}${LS} -l ${CURDIR}/${GCEFILE}
	${_v}${TOUCH} ${WRKDIR}/.gce_done
	@echo " done"
.endif

iso: config boot mfsroot ${WRKDIR}/.iso_done
${WRKDIR}/.iso_done:
	@echo "---------------------------------------------------- $(@F)"
	@echo "Creating ISO image - ${ISOIMAGE} ..."
	${_v}if [ -f ${CURDIR}/${ISOIMAGE} ]; then \
		${RM} ${CURDIR}/${ISOIMAGE} ; \
	fi

	${_v}${MAKEFS} -t cd9660 -o rockridge,bootimage=i386\;/boot/cdboot,no-emul-boot,label=mfsBSD ${ISOIMAGE} ${WRKDIR}/disk
	${_v}${LS} -l ${CURDIR}/${ISOIMAGE}
	${_v}${TOUCH} ${WRKDIR}/.iso_done
	@echo " done"

tar: config boot mfsroot ${WRKDIR}/.tar_done
${WRKDIR}/.tar_done:
	@echo "---------------------------------------------------- $(@F)"
	@echo "Creating tar file - ${TARFILE} ..."
	${_v}if [ -f ${CURDIR}/${TARFILE} ]; then \
		${RM} ${CURDIR}/${TARFILE} ; \
	fi
	${_v}cd ${WRKDIR}/disk && ${FIND} . -depth 1 \
		-exec ${TAR} -r -f ${CURDIR}/${TARFILE} {} \;
	${_v}${LS} -l ${CURDIR}/${TARFILE}
	${_v}${TOUCH} ${WRKDIR}/.tar_done
	${_v}echo " done"

clean: ${WRKDIR}/.clean_done
${WRKDIR}/.clean_done:
	@echo "---------------------------------------------------- $(@F)"
	${_v}if [ -d ${WRKDIR} ]; then \
	${CHFLAGS} -R noschg ${WRKDIR} && \
	cd ${WRKDIR} && ${RM} -rf mfs mnt disk dist trees .*_done; \
	fi
	${_v}echo " done"
