# $Id$
#
# mfsBSD
# Copyright (c) 2007-2013 Martin Matuska <mm at FreeBSD.org>
#
# Version 2.1
#

#
# User-defined variables
#
BASE?=/cdrom/usr/freebsd-dist
KERNCONF?= GENERIC
MFSROOT_FREE_INODES?=10%
MFSROOT_FREE_BLOCKS?=10%
MFSROOT_MAXSIZE?=64m

# If you want to build your own kernel and make you own world, you need to set
# -DCUSTOM or CUSTOM=1
#
# To make buildworld use 
# -DCUSTOM -DBUILDWORLD or CUSTOM=1 BUILDWORLD=1
#
# To make buildkernel use
# -DCUSTOM -DBUILDKERNEL or CUSTOM=1 BUILDKERNEL=1
#
# For all of this use
# -DCUSTOM -DBUILDWORLD -DBUILDKERNEL or CUSTOM=1 BUILDKERNEL=1 BUILDWORLD=1
#
# To use pkgng, specify
# -DPKGNG or PKGNG=1

#
# Paths
#
SRC_DIR?=/usr/src
CFGDIR=conf
SCRIPTSDIR=scripts
PACKAGESDIR?=packages
CUSTOMFILESDIR=customfiles
TOOLSDIR=tools
PRUNELIST?=${TOOLSDIR}/prunelist
PKG_STATIC?=${TOOLSDIR}/pkg-static
#
# Program defaults
#
MKDIR=/bin/mkdir -p
CHOWN=/usr/sbin/chown
CAT=/bin/cat
PWD=/bin/pwd
TAR=/usr/bin/tar
GTAR=/usr/local/bin/gtar
CP=/bin/cp
MV=/bin/mv
RM=/bin/rm
RMDIR=/bin/rmdir
CHFLAGS=/bin/chflags
GZIP=/usr/bin/gzip
TOUCH=/usr/bin/touch
INSTALL=/usr/bin/install
LS=/bin/ls
LN=/bin/ln
FIND=/usr/bin/find
GREP=/usr/bin/egrep
PW=/usr/sbin/pw
SED=/usr/bin/sed
UNAME=/usr/bin/uname
BZIP2=/usr/bin/bzip2
XZ=/usr/bin/xz
MAKEFS=/usr/sbin/makefs
MKISOFS=/usr/local/bin/mkisofs
SSHKEYGEN=/usr/bin/ssh-keygen
SYSCTL=/sbin/sysctl
PKG=/usr/local/sbin/pkg
#
CURDIR!=${PWD}
WRKDIR?=${CURDIR}/tmp
#
BSDLABEL=bsdlabel
#
DOFS=${TOOLSDIR}/doFS.sh
SCRIPTS?=mdinit mfsbsd interfaces packages
BOOTMODULES?=acpi ahci aesni
MFSMODULES?=geom_mirror geom_nop opensolaris zfs geom_eli crypto zlib \
  geom_label ext2fs snp smbus ipmi ntfs nullfs tmpfs aesni
#

.if !defined(ARCH)
TARGET!=	${SYSCTL} -n hw.machine_arch
.else
TARGET=		${ARCH}
.endif

.if !defined(RELEASE)
RELEASE!=${UNAME} -r
.endif

.if !defined(SE)
IMAGE_PREFIX?=	mfsbsd
.else
IMAGE_PREFIX?=	mfsbsd-se
.endif

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

# Roothack stuff
.if defined(ROOTHACK_FILE) && exists(${ROOTHACK_FILE})
ROOTHACK=1
ROOTHACK_PREBUILT=1
_ROOTHACK_FILE=${ROOTHACK_FILE}
.else
_ROOTHACK_FILE=${WRKDIR}/roothack/roothack
.endif

# Check if we are installing FreeBSD 9 or higher
.if exists(${BASE}/base.txz) && exists(${BASE}/kernel.txz)
FREEBSD9?=yes
BASEFILE?=${BASE}/base.txz
KERNELFILE?=${BASE}/kernel.txz
.else
BASEFILE?=${BASE}/base/base.??
KERNELFILE?=${BASE}/kernels/generic.??
.endif

.if defined(MAKEJOBS)
_MAKEJOBS=	-j${MAKEJOBS}
.endif

_ROOTDIR=	${WRKDIR}/mfs
_BOOTDIR=	${_ROOTDIR}/boot
.if defined(ROOTHACK)
_DESTDIR=	${_ROOTDIR}/rw
WITHOUT_RESCUE=1
MFSROOT_FREE_INODES?=1%
MFSROOT_FREE_BLOCKS?=1%
.else
_DESTDIR=	${_ROOTDIR}
.endif

.if !defined(SE)
# Environment for custom build
BUILDENV?= env \
	NO_FSCHG=1 \
	WITHOUT_CLANG=1 \
	WITHOUT_DICT=1 \
	WITHOUT_GAMES=1 \
	WITHOUT_LIB32=1

. if defined(WITHOUT_RESCUE)
BUILDENV+=	WITHOUT_RESCUE=1
. endif

# Environment for custom install
INSTALLENV?= ${BUILDENV} \
	WITHOUT_TOOLCHAIN=1
.endif

all: image

destdir: ${_DESTDIR} ${_BOOTDIR}
${_DESTDIR}:
	@${MKDIR} ${_DESTDIR} && ${CHOWN} root:wheel ${_DESTDIR}

${_BOOTDIR}:
	@${MKDIR} ${_BOOTDIR}/kernel ${_BOOTDIR}/modules && ${CHOWN} -R root:wheel ${_BOOTDIR}

extract: destdir ${WRKDIR}/.extract_done
${WRKDIR}/.extract_done:
.if !defined(CUSTOM)
	@if [ ! -d "${BASE}" ]; then \
		echo "Please set the environment variable BASE to a path"; \
		echo "with FreeBSD distribution files (e.g. /cdrom/9.2-RELEASE)"; \
		echo "Examples:"; \
		echo "make BASE=/cdrom/9.2-RELEASE"; \
		echo "make BASE=/cdrom/usr/freebsd-dist"; \
		exit 1; \
	fi
.if !defined(FREEBSD9)
	@for DIR in base kernels; do \
		if [ ! -d "${BASE}/$$DIR" ]; then \
			echo "Cannot find directory \"${BASE}/$$DIR\""; \
			exit 1; \
		fi \
	done
.endif
	@echo -n "Extracting base and kernel ..."
	@${CAT} ${BASEFILE} | ${TAR} --unlink -xpzf - -C ${_DESTDIR}
.if !defined(FREEBSD9)
	@${CAT} ${KERNELFILE} | ${TAR} --unlink -xpzf - -C ${_BOOTDIR}
	@${MV} ${_BOOTDIR}/${KERNCONF}/* ${_BOOTDIR}/kernel
	@${RMDIR} ${_BOOTDIR}/${KERNCONF}
.else
	@${CAT} ${KERNELFILE} | ${TAR} --unlink -xpzf - -C ${_ROOTDIR}
.endif
	@echo " done"
.endif
	@${TOUCH} ${WRKDIR}/.extract_done

build: extract ${WRKDIR}/.build_done
${WRKDIR}/.build_done:
.if defined(CUSTOM)
. if defined(BUILDWORLD)
	@echo -n "Building world ..."
	@cd ${SRC_DIR} && \
	${BUILDENV} make ${_MAKEJOBS} buildworld TARGET=${TARGET}
. endif
. if defined(BUILDKERNEL)
	@echo -n "Building kernel KERNCONF=${KERNCONF} ..."
	@cd ${SRC_DIR} && make buildkernel KERNCONF=${KERNCONF} TARGET=${TARGET}
. endif
.endif
	@${TOUCH} ${WRKDIR}/.build_done

install: destdir build ${WRKDIR}/.install_done
${WRKDIR}/.install_done:
.if defined(CUSTOM)
	@echo -n "Installing world and kernel KERNCONF=${KERNCONF} ..."
	@cd ${SRC_DIR} && \
	${INSTALLENV} make installworld distribution DESTDIR="${_DESTDIR}" TARGET=${TARGET} && \
	${INSTALLENV} make installkernel KERNCONF=${KERNCONF} DESTDIR="${_ROOTDIR}" TARGET=${TARGET}
.endif
.if defined(SE)
. if !defined(CUSTOM) && exists(${BASE}/base.txz) && exists(${BASE}/kernel.txz)
	@echo -n "Copying base.txz and kernel.txz ..."
. else
	@echo -n "Creating base.txz and kernel.txz ..."
. endif
	@${MKDIR} ${_DISTDIR}
. if defined(ROOTHACK)
	@${CP} -rp ${_BOOTDIR}/kernel ${_DESTDIR}/boot
. endif
. if !defined(CUSTOM) && exists(${BASE}/base.txz) && exists(${BASE}/kernel.txz)
	@${CP} ${BASE}/base.txz ${_DISTDIR}/base.txz
	@${CP} ${BASE}/kernel.txz ${_DISTDIR}/kernel.txz
. else
	@${TAR} -c -C ${_DESTDIR} -J ${EXCLUDE} --exclude "boot/kernel/*" -f ${_DISTDIR}/base.txz .
	@${TAR} -c -C ${_DESTDIR} -J ${EXCLUDE} -f ${_DISTDIR}/kernel.txz boot/kernel
. endif
	@echo " done"
. if defined(ROOTHACK)
	@${RM} -rf ${_DESTDIR}/boot/kernel
. endif
.endif
	@${CHFLAGS} -R noschg ${_DESTDIR} > /dev/null 2> /dev/null || exit 0
.if !defined(WITHOUT_RESCUE)
	@cd ${_DESTDIR} && \
	for FILE in `${FIND} rescue -type f`; do \
	FILE=$${FILE##rescue/}; \
	if [ -f bin/$$FILE ]; then \
		${RM} bin/$$FILE && \
		${LN} rescue/$$FILE bin/$$FILE; \
	elif [ -f sbin/$$FILE ]; then \
		${RM} sbin/$$FILE && \
		${LN} rescue/$$FILE sbin/$$FILE; \
	elif [ -f usr/bin/$$FILE ]; then \
		${RM} usr/bin/$$FILE && \
		${LN} -s ../../rescue/$$FILE usr/bin/$$FILE; \
	elif [ -f usr/sbin/$$FILE ]; then \
		${RM} usr/sbin/$$FILE && \
		${LN} -s ../../rescue/$$FILE usr/sbin/$$FILE; \
	fi; \
	done
.else
	@cd ${_DESTDIR} && ${RM} -rf rescue
.endif
	@${TOUCH} ${WRKDIR}/.install_done

prune: install ${WRKDIR}/.prune_done
${WRKDIR}/.prune_done:
	@echo -n "Removing selected files from distribution ..."
	@if [ -f "${PRUNELIST}" ]; then \
		for FILE in `cat ${PRUNELIST}`; do \
			if [ -n "$${FILE}" ]; then \
				${RM} -rf ${_DESTDIR}/$${FILE}; \
			fi; \
		done; \
	fi
	@${TOUCH} ${WRKDIR}/.prune_done
	@echo " done"

packages: install prune ${WRKDIR}/.packages_done
${WRKDIR}/.packages_done:
.if defined(PKGNG)
	@echo -n "Installing pkgng ..."
.  if !exists(${PKG_STATIC})
	@echo "pkg-static not found at: ${PKG_STATIC}"
	@exit 1
.  endif
	@mkdir -p ${_DESTDIR}/usr/local/sbin
	@${INSTALL} -o root -g wheel -m 0755 ${PKG_STATIC} ${_DESTDIR}/usr/local/sbin/
	@${LN} -sf pkg-static ${_DESTDIR}/usr/local/sbin/pkg
	@echo " done"
.endif
	@if [ -d "${PACKAGESDIR}" ]; then \
		echo -n "Copying user packages ..."; \
		${CP} -rf ${PACKAGESDIR} ${_DESTDIR}; \
		echo " done"; \
	fi
	@if [ -d "${_DESTDIR}/packages" ]; then \
		echo -n "Installing user packages ..."; \
	fi
.if defined(PKGNG)
	@if [ -d "${_DESTDIR}/packages" ]; then \
		cd ${_DESTDIR}/packages && for FILE in *; do \
			${PKG} -c ${_DESTDIR} add /packages/$${FILE}; \
		done; \
	fi
.else
	@if [ -d "${_DESTDIR}/packages" ]; then \
		cd ${_DESTDIR}/packages && for FILE in *; do \
			env PKG_PATH=/packages pkg_add -fi -C ${_DESTDIR} /packages/$${FILE} > /dev/null; \
		done; \
	fi
.endif
	@if [ -d "${_DESTDIR}/packages" ]; then \
		${RM} -rf ${_DESTDIR}/packages; \
		echo " done"; \
	fi
	@${TOUCH} ${WRKDIR}/.packages_done

config: install ${WRKDIR}/.config_done
${WRKDIR}/.config_done:
	@echo -n "Installing configuration scripts and files ..."
.for FILE in boot.config loader.conf rc.conf rc.local resolv.conf interfaces.conf ttys
. if !exists(${CFGDIR}/${FILE}) && !exists(${CFGDIR}/${FILE}.sample)
	@echo "Missing ${CFGDIR}/${FILE}.sample" && exit 1
. endif
.endfor
.if defined(SE)
	@${INSTALL} -m 0644 ${TOOLSDIR}/motd.se ${_DESTDIR}/etc/motd
	@${INSTALL} -d -m 0755 ${_DESTDIR}/cdrom
.else
	@${INSTALL} -m 0644 ${TOOLSDIR}/motd ${_DESTDIR}/etc/motd
.endif
	@${MKDIR} ${_DESTDIR}/stand ${_DESTDIR}/etc/rc.conf.d
	@if [ -f "${CFGDIR}/boot.config" ]; then \
		${INSTALL} -m 0644 ${CFGDIR}/boot.config ${_ROOTDIR}/boot.config; \
	else \
		${INSTALL} -m 0644 ${CFGDIR}/boot.config.sample ${_ROOTDIR}/boot.config; \
	fi
	@if [ -f "${CFGDIR}/loader.conf" ]; then \
		${INSTALL} -m 0644 ${CFGDIR}/loader.conf ${_BOOTDIR}/loader.conf; \
	else \
		${INSTALL} -m 0644 ${CFGDIR}/loader.conf.sample ${_BOOTDIR}/loader.conf; \
	fi
	@if [ -f "${CFGDIR}/rc.local" ]; then \
		${INSTALL} -m 0744 ${CFGDIR}/rc.local ${_DESTDIR}/etc/rc.local; \
   else \
		${INSTALL} -m 0744 ${CFGDIR}/rc.local.sample ${_DESTDIR}/etc/rc.local; \
   fi
.for FILE in rc.conf ttys
	@if [ -f "${CFGDIR}/${FILE}" ]; then \
		${INSTALL} -m 0644 ${CFGDIR}/${FILE} ${_DESTDIR}/etc/${FILE}; \
	else \
		${INSTALL} -m 0644 ${CFGDIR}/${FILE}.sample ${_DESTDIR}/etc/${FILE}; \
	fi
.endfor
.if defined(ROOTHACK)
	@echo 'root_rw_mount="NO"' >> ${_DESTDIR}/etc/rc.conf
.endif
	@if [ -f "${CFGDIR}/resolv.conf" ]; then \
		${INSTALL} -m 0644 ${CFGDIR}/resolv.conf ${_DESTDIR}/etc/resolv.conf; \
	fi
	@if [ -f "${CFGDIR}/interfaces.conf" ]; then \
		${INSTALL} -m 0644 ${CFGDIR}/interfaces.conf ${_DESTDIR}/etc/rc.conf.d/interfaces; \
	fi
	@if [ -f "${CFGDIR}/authorized_keys" ]; then \
		${INSTALL} -d -m 0700 ${_DESTDIR}/root/.ssh; \
		${INSTALL} ${CFGDIR}/authorized_keys ${_DESTDIR}/root/.ssh/; \
	fi
	@${MKDIR} ${_DESTDIR}/root/bin
	@${INSTALL} ${TOOLSDIR}/zfsinstall ${_DESTDIR}/root/bin
	@${INSTALL} ${TOOLSDIR}/destroygeom ${_DESTDIR}/root/bin
	@for SCRIPT in ${SCRIPTS}; do \
		${INSTALL} -m 0555 ${SCRIPTSDIR}/$${SCRIPT} ${_DESTDIR}/etc/rc.d/; \
	done
#	@${SED} -I -E 's/\(ttyv[2-7].*\)on /\1off/g' ${_DESTDIR}/etc/ttys
.if !defined(ROOTHACK)
	@echo "/dev/md0 / ufs rw 0 0" > ${_DESTDIR}/etc/fstab
	@echo "tmpfs /tmp tmpfs rw,mode=1777 0 0" >> ${_DESTDIR}/etc/fstab
.else
	@${TOUCH} ${_DESTDIR}/etc/fstab
.endif
.if defined(ROOTPW)
	@echo ${ROOTPW} | ${PW} -V ${_DESTDIR}/etc usermod root -h 0
.endif
	@echo PermitRootLogin yes >> ${_DESTDIR}/etc/ssh/sshd_config
.if exists(${CFGDIR}/hosts)
	@${INSTALL} -m 0644 ${CFGDIR}/hosts ${_DESTDIR}/etc/hosts
.elif exists(${CFGDIR}/hosts.sample)
	@${INSTALL} -m 0644 ${CFGDIR}/hosts.sample ${_DESTDIR}/etc/hosts
.else
	@echo "Missing ${CFGDIR}/hosts.sample" && exit 1
.endif
	@${TOUCH} ${WRKDIR}/.config_done
	@echo " done"

genkeys: config ${WRKDIR}/.genkeys_done
${WRKDIR}/.genkeys_done:
	@echo -n "Generating SSH host keys ..."
	@${SSHKEYGEN} -t rsa1 -b 1024 -f ${_DESTDIR}/etc/ssh/ssh_host_key -N '' > /dev/null
	@${SSHKEYGEN} -t dsa -f ${_DESTDIR}/etc/ssh/ssh_host_dsa_key -N '' > /dev/null
	@${SSHKEYGEN} -t rsa -f ${_DESTDIR}/etc/ssh/ssh_host_rsa_key -N '' > /dev/null
	@${TOUCH} ${WRKDIR}/.genkeys_done
	@echo " done"

customfiles: config ${WRKDIR}/.customfiles_done
${WRKDIR}/.customfiles_done:
.if exists(${CUSTOMFILESDIR})
	@echo "Copying user files ..."
	@${CP} -afv ${CUSTOMFILESDIR}/ ${_DESTDIR}/
	@${TOUCH} ${WRKDIR}/.customfiles_done
	@echo " done"
.endif

compress-usr: install prune config genkeys customfiles boot packages ${WRKDIR}/.compress-usr_done
${WRKDIR}/.compress-usr_done:
.if !defined(ROOTHACK)
	@echo -n "Compressing usr ..."
	@${TAR} -c -J -C ${_DESTDIR} -f ${_DESTDIR}/.usr.tar.xz usr 
	@${RM} -rf ${_DESTDIR}/usr && ${MKDIR} ${_DESTDIR}/usr 
.else
	@echo -n "Compressing root ..."
	@${TAR} -c -C ${_ROOTDIR} -f - rw | \
	${XZ} -v -c > ${_ROOTDIR}/root.txz
	@${RM} -rf ${_DESTDIR} && ${MKDIR} ${_DESTDIR}
.endif
	@${TOUCH} ${WRKDIR}/.compress-usr_done
	@echo " done"

roothack: ${WRKDIR}/roothack/roothack
${WRKDIR}/roothack/roothack:
.if !defined(ROOTHACK_PREBUILT)
	@${MKDIR} -p ${WRKDIR}/roothack
	@cd ${TOOLSDIR}/roothack && env MAKEOBJDIR=${WRKDIR}/roothack make
.endif

install-roothack: compress-usr roothack ${WRKDIR}/.install-roothack_done
${WRKDIR}/.install-roothack_done:
	@echo -n "Installing roothack ..."
	@${MKDIR} -p ${_ROOTDIR}/dev ${_ROOTDIR}/sbin
	@${INSTALL} -m 555 ${_ROOTHACK_FILE} ${_ROOTDIR}/sbin/init
	@${TOUCH} ${WRKDIR}/.install-roothack_done
	@echo " done"

boot: install prune ${WRKDIR}/.boot_done
${WRKDIR}/.boot_done:
	@echo -n "Configuring boot environment ..."
	@${MKDIR} ${WRKDIR}/disk/boot && ${CHOWN} root:wheel ${WRKDIR}/disk
	@${RM} -f ${_BOOTDIR}/kernel/kernel.debug
	@${CP} -rp ${_BOOTDIR}/kernel ${WRKDIR}/disk/boot
.for FILE in boot defaults loader loader.help *.rc *.4th
	@${CP} -rp ${_DESTDIR}/boot/${FILE} ${WRKDIR}/disk/boot
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
	@${MKDIR} -p ${_DESTDIR}/boot/modules
.for FILE in ${MFSMODULES}
	@test -f ${_BOOTDIR}/kernel/${FILE}.ko \
	&& ${INSTALL} -m 0555 ${_BOOTDIR}/kernel/${FILE}.ko ${_DESTDIR}/boot/modules >/dev/null 2>/dev/null || exit 0
. if defined(DEBUG)
	@test -f ${_BOOTDIR}/kernel/${FILE}.ko.symbols \
	&& ${INSTALL} -m 0555 ${_BOOTDIR}/kernel/${FILE}.ko.symbols ${_DESTDIR}/boot/modules >/dev/null 2>/dev/null || exit 0
. endif
.endfor
.if defined(ROOTHACK)
	@echo -n "Installing tmpfs module for roothack ..."
	@${MKDIR} -p ${_ROOTDIR}/boot/modules
	@${INSTALL} -m 0666 ${_BOOTDIR}/kernel/tmpfs.ko ${_ROOTDIR}/boot/modules
	@echo " done"
.endif
	@${RM} -rf ${_BOOTDIR}/kernel ${_BOOTDIR}/*.symbols
	@${TOUCH} ${WRKDIR}/.boot_done
	@echo " done"

.if defined(ROOTHACK)
mfsroot: install prune config genkeys customfiles boot compress-usr packages install-roothack ${WRKDIR}/.mfsroot_done
.else
mfsroot: install prune config genkeys customfiles boot compress-usr packages ${WRKDIR}/.mfsroot_done
.endif
${WRKDIR}/.mfsroot_done:
	@echo -n "Creating and compressing mfsroot ..."
	@${MKDIR} ${WRKDIR}/mnt
	@${MAKEFS} -t ffs -m ${MFSROOT_MAXSIZE} -f ${MFSROOT_FREE_INODES} -b ${MFSROOT_FREE_BLOCKS} ${WRKDIR}/disk/mfsroot ${_ROOTDIR} > /dev/null
	@${RM} -rf ${WRKDIR}/mnt ${_DESTDIR}
	@${GZIP} -9 -f ${WRKDIR}/disk/mfsroot
	@${GZIP} -9 -f ${WRKDIR}/disk/boot/kernel/kernel
	@if [ -f "${CFGDIR}/loader.conf" ]; then \
		${INSTALL} -m 0644 ${CFGDIR}/loader.conf ${WRKDIR}/disk/boot/loader.conf; \
	else \
		${INSTALL} -m 0644 ${CFGDIR}/loader.conf.sample ${WRKDIR}/disk/boot/loader.conf; \
	fi
	@${TOUCH} ${WRKDIR}/.mfsroot_done
	@echo " done"

fbsddist: install prune config genkeys customfiles boot compress-usr packages mfsroot ${WRKDIR}/.fbsddist_done
${WRKDIR}/.fbsddist_done:
.if defined(SE)
	@echo -n "Copying FreeBSD installation image ..."
	@${CP} -rf ${_DISTDIR} ${WRKDIR}/disk/
	@echo " done"
.endif
	@${TOUCH} ${WRKDIR}/.fbsddist_done

image: install prune config genkeys customfiles boot compress-usr mfsroot fbsddist ${IMAGE}
${IMAGE}:
	@echo -n "Creating image file ..."
	@${MKDIR} ${WRKDIR}/mnt ${WRKDIR}/trees/base/boot
	@${INSTALL} -m 0444 ${WRKDIR}/disk/boot/boot ${WRKDIR}/trees/base/boot/
	@${DOFS} ${BSDLABEL} "" ${WRKDIR}/disk.img ${WRKDIR} ${WRKDIR}/mnt 0 ${WRKDIR}/disk 80000 auto > /dev/null 2> /dev/null
	@${RM} -rf ${WRKDIR}/mnt ${WRKDIR}/trees
	@${MV} ${WRKDIR}/disk.img ${IMAGE}
	@echo " done"
	@${LS} -l ${IMAGE}

gce: install prune config genkeys customfiles boot compress-usr mfsroot fbsddist ${IMAGE} ${GCEFILE}
${GCEFILE}:
	@echo -n "Creating GCE-compatible tarball..."
.if !exists(${GTAR})
	@echo "${GTAR} is missing, please install archivers/gtar first"; exit 1
.else
	@${GTAR} -C ${CURDIR} -Szcf ${GCEFILE} --transform='s/${IMAGE}/disk.raw/' ${IMAGE}
	@echo " GCE tarball built"
	@${LS} -l ${GCEFILE}
.endif

iso: install prune config genkeys customfiles boot compress-usr mfsroot fbsddist ${ISOIMAGE}
${ISOIMAGE}:
	@echo -n "Creating ISO image ..."
.if defined(USE_MKISOFS)
. if !exists(${MKISOFS})
	@echo "${MKISOFS} is missing, please install sysutils/cdrtools first"; exit 1
. else
	@${MKISOFS} -b boot/cdboot -no-emul-boot -r -J -V mfsBSD -o ${ISOIMAGE} ${WRKDIR}/disk > /dev/null 2> /dev/null
. endif
.else
	@${MAKEFS} -t cd9660 -o rockridge,bootimage=i386\;/boot/cdboot,no-emul-boot,label=mfsBSD ${ISOIMAGE} ${WRKDIR}/disk
.endif
	@echo " done"
	@${LS} -l ${ISOIMAGE}

tar: install prune config customfiles boot compress-usr mfsroot fbsddist ${TARFILE}
${TARFILE}:
	@echo -n "Creating tar file ..."
	@cd ${WRKDIR}/disk && ${FIND} . -depth 1 \
		-exec ${TAR} -r -f ${CURDIR}/${TARFILE} {} \;
	@echo " done"
	@${LS} -l ${TARFILE}

clean-roothack:
	@${RM} -rf ${WRKDIR}/roothack

clean: clean-roothack
	@if [ -d ${WRKDIR} ]; then ${CHFLAGS} -R noschg ${WRKDIR}; fi
	@cd ${WRKDIR} && ${RM} -rf mfs mnt disk dist trees .*_done
