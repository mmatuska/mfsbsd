# $Id$
#
# mfsBSD
# Copyright (c) 2007-2012 Martin Matuska <mm at FreeBSD.org>
#
# Version 1.1.1
#

#
# User-defined variables
#
BASE?=/cdrom/usr/freebsd-dist
KERNCONF?= GENERIC
MFSROOT_FREE_INODES?=10%
MFSROOT_FREE_BLOCKS?=10%
MFSROOT_MAXSIZE?=64m
ROOTPW?= mfsroot

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
# Paths
#
SRC_DIR?=/usr/src
CFGDIR=conf
SCRIPTSDIR=scripts
PACKAGESDIR?=packages
FILESDIR=files
TOOLSDIR=tools
PRUNELIST?=${TOOLSDIR}/prunelist
#
# Program defaults
#
MKDIR=/bin/mkdir -p
CHOWN=/usr/sbin/chown
CAT=/bin/cat
PWD=/bin/pwd
TAR=/usr/bin/tar
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
PW=/usr/sbin/pw
SED=/usr/bin/sed
UNAME=/usr/bin/uname
BZIP2=/usr/bin/bzip2
XZ=/usr/bin/xz
MAKEFS=/usr/sbin/makefs
MKISOFS=/usr/local/bin/mkisofs
SSHKEYGEN=/usr/bin/ssh-keygen
SYSCTL=/sbin/sysctl
#
CURDIR!=${PWD}
WRKDIR?=${CURDIR}/tmp
#
BSDLABEL=bsdlabel
#
DOFS=${TOOLSDIR}/doFS.sh
SCRIPTS=mdinit mfsbsd interfaces packages
BOOTMODULES=acpi ahci
MFSMODULES=geom_mirror opensolaris zfs ext2fs snp smbus ipmi ntfs nullfs tmpfs
#
COMPRESS?=	xz

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

.if defined(COMPRESS)
. if ${COMPRESS} == "xz"
COMPRESS_CMD=${XZ}
SUFX=".xz"
. elif ${COMPRESS} == "bzip2"
COMPRESS_CMD=${BZIP2}
SUFX=".bz2"
. else
COMPRESS_CMD=${GZIP}
SUFX=".gz"
. endif
.endif

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
MFSROOT_FREE_INODES=1%
MFSROOT_FREE_BLOCKS=1%
.else
_DESTDIR=	${_ROOTDIR}
.endif

.if !defined(SE)
# Envirnoment for custom build
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
		echo "with FreeBSD distribution files (e.g. /cdrom/8.3-RELEASE)"; \
		echo "Examples:"; \
		echo "make BASE=/cdrom/8.3-RELEASE"; \
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
	@${MV} ${_BOOTDIR}/GENERIC/* ${_BOOTDIR}/kernel
	@${RMDIR} ${_BOOTDIR}/GENERIC
.else
	@${CAT} ${KERNELFILE} | ${TAR} --unlink -xpzf - -C ${_ROOTDIR}
.endif
	@echo " done"
.endif
	@${TOUCH} ${WRKDIR}/.extract_done

build: extract ${WRKDIR}/.build_done
${WRKDIR}/.build_done:
.if defined(CUSTOM)
. if defined(BUILDKERNEL)
	@echo -n "Building kernel KERNCONF=${KERNCONF} ..."
	@cd ${SRC_DIR} && make buildkernel KERNCONF=${KERNCONF} TARGET=${TARGET}
. endif
. if defined(BUILDWORLD)
	@echo -n "Building world ..."
	@cd ${SRC_DIR} && \
	${BUILDENV} make ${_MAKEJOBS} buildworld TARGET=${TARGET}
. endif
.endif
	@${TOUCH} ${WRKDIR}/.build_done

install: destdir build ${WRKDIR}/.install_done
${WRKDIR}/.install_done:
.if defined(CUSTOM)
	@echo -n "Installing world and kernel KERNCONF=${KERNCONF} ..."
	@cd ${SRC_DIR} && \
	${INSTALLENV} make installworld distribution DESTDIR="${_DESTDIR}" TARGET=${TARGET} && \
	${INSTALLENV} make installkernel DESTDIR="${_ROOTDIR}" TARGET=${TARGET}
.endif
.if defined(SE)
	@echo -n "Creating FreeBSD distribution image ..."
	@${MKDIR} ${WRKDIR}/dist
	@${CP} -rp ${_BOOTDIR}/kernel ${_DESTDIR}/boot
	@cd ${_DESTDIR} && ${FIND} . -depth 1 \
		-exec ${TAR} -r ${EXCLUDE} -f ${WRKDIR}/dist/${RELEASE}-${TARGET}.tar {} \; 
	@echo " done"
. if defined(COMPRESS)
	@echo "Compressing FreeBSD distribution image ..."
	@${COMPRESS_CMD} -v ${WRKDIR}/dist/${RELEASE}-${TARGET}.tar
. endif
	@${RM} -rf ${_DESTDIR}/boot/kernel
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
	@if [ -d "${PACKAGESDIR}" ]; then \
		echo -n "Copying user packages ..."; \
		${CP} -rf ${PACKAGESDIR} ${_DESTDIR}/packages; \
		echo " done"; \
	fi
	@if [ -d "${_DESTDIR}/packages" ]; then \
		echo -n "Installing user packages ..."; \
		cd ${_DESTDIR}/packages && for FILE in *; do \
			env PKG_PATH=/packages pkg_add -fi -C ${_DESTDIR} /packages/$${FILE} > /dev/null; \
		done; \
		rm -rf ${_DESTDIR}/packages; \
		echo " done"; \
	fi
	@${TOUCH} ${WRKDIR}/.packages_done

config: install ${WRKDIR}/.config_done
${WRKDIR}/.config_done:
	@echo -n "Installing configuration scripts and files ..."
.for FILE in loader.conf rc.conf resolv.conf interfaces.conf ttys
. if !exists(${CFGDIR}/${FILE}) && !exists(${CFGDIR}/${FILE}.sample)
	@echo "Missing ${CFGDIR}/$${FILE}.sample" && exit 1
. endif
.endfor
.if defined(SE)
	@${INSTALL} -m 0644 ${TOOLSDIR}/motd.se ${_DESTDIR}/etc/motd
	@${INSTALL} -d -m 0755 ${_DESTDIR}/cdrom
.else
	@${INSTALL} -m 0644 ${TOOLSDIR}/motd ${_DESTDIR}/etc/motd
.endif
	@${MKDIR} ${_DESTDIR}/stand ${_DESTDIR}/etc/rc.conf.d
	@if [ -f "${CFGDIR}/loader.conf" ]; then \
		${INSTALL} -m 0644 ${CFGDIR}/loader.conf ${_BOOTDIR}/loader.conf; \
	else \
		${INSTALL} -m 0644 ${CFGDIR}/loader.conf.sample ${_BOOTDIR}/loader.conf; \
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
	@${SED} -I -E 's/\(ttyv[2-7].*\)on /\1off/g' ${_DESTDIR}/etc/ttys
.if !defined(ROOTHACK)
	@echo "/dev/md0 / ufs rw 0 0" > ${_DESTDIR}/etc/fstab
	@echo "tmpfs /tmp tmpfs rw,mode=1777 0 0" >> ${_DESTDIR}/etc/fstab
.else
	@${TOUCH} ${_DESTDIR}/etc/fstab
.endif
	@echo ${ROOTPW} | ${PW} -V ${_DESTDIR}/etc usermod root -h 0
	@echo PermitRootLogin yes >> ${_DESTDIR}/etc/ssh/sshd_config
	@echo 127.0.0.1 localhost > ${_DESTDIR}/etc/hosts
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

compress-usr: install prune config genkeys boot packages ${WRKDIR}/.compress-usr_done
${WRKDIR}/.compress-usr_done:
.if !defined(ROOTHACK)
	@echo -n "Compressing usr ..."
	@${TAR} -c -C ${_DESTDIR} -f - usr | \
	${COMPRESS_CMD} -v -c > ${_DESTDIR}/.usr.tar${SUFX} && \
	${RM} -rf ${_DESTDIR}/usr && \
	${MKDIR} ${_DESTDIR}/usr
.else
	@echo -n "Compressing root ..."
	@${TAR} -c -C ${_ROOTDIR} -f - rw | \
	${COMPRESS_CMD} -v -c > ${_ROOTDIR}/root.txz
	${RM} -rf ${_DESTDIR} && ${MKDIR} ${_DESTDIR}
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
mfsroot: install prune config genkeys boot compress-usr packages install-roothack ${WRKDIR}/.mfsroot_done
.else
mfsroot: install prune config genkeys boot compress-usr packages ${WRKDIR}/.mfsroot_done
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

fbsddist: install prune config genkeys boot compress-usr packages mfsroot ${WRKDIR}/.fbsddist_done
${WRKDIR}/.fbsddist_done:
.if defined(SE)
	@echo -n "Copying FreeBSD installation image ..."
	@${CP} ${WRKDIR}/dist/${RELEASE}-${TARGET}.tar${SUFX} ${WRKDIR}/disk/
	@echo " done"
.endif
	@${TOUCH} ${WRKDIR}/.fbsddist_done

image: install prune config genkeys boot compress-usr mfsroot fbsddist ${IMAGE}
${IMAGE}:
	@echo -n "Creating image file ..."
	@${MKDIR} ${WRKDIR}/mnt ${WRKDIR}/trees/base/boot
	@${INSTALL} -m 0444 ${WRKDIR}/disk/boot/boot ${WRKDIR}/trees/base/boot/
	@${DOFS} ${BSDLABEL} "" ${WRKDIR}/disk.img ${WRKDIR} ${WRKDIR}/mnt 0 ${WRKDIR}/disk 80000 auto > /dev/null 2> /dev/null
	@${RM} -rf ${WRKDIR}/mnt ${WRKDIR}/trees
	@${MV} ${WRKDIR}/disk.img ${IMAGE}
	@echo " done"
	@${LS} -l ${IMAGE}

iso: install prune config genkeys boot compress-usr mfsroot fbsddist ${ISOIMAGE}
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

tar: install prune config boot compress-usr mfsroot fbsddist ${TARFILE}
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
