# $Id$
#
# mfsBSD
# Copyright (c) 2007-2010 Martin Matuska <mm at FreeBSD.org>
#
# Version 1.0
#

#
# User-defined variables
#
BASE?=/cdrom/8.0-RELEASE
IMAGE?=	mfsboot.img
ISOIMAGE?= mfsboot.iso
TARFILE?= mfsboot.tar
KERNCONF?= GENERIC
MFSROOT_FREE_INODES?=5%
MFSROOT_FREE_BLOCKS?=5%
MFSROOT_MAXSIZE?=45m
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
PACKAGESDIR=packages
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
MKUZIP=/usr/bin/mkuzip
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
SSHKEYGEN=/usr/bin/ssh-keygen
SYSCTL=/sbin/sysctl
MKISOFS=/usr/local/bin/mkisofs
#
CURDIR!=${PWD}
WRKDIR?=${CURDIR}/tmp
#
BSDLABEL=bsdlabel
#
DOFS=${TOOLSDIR}/doFS.sh
SCRIPTS=mdinit mfsbsd interfaces packages
BOOTMODULES=acpi snp opensolaris zfs
MFSMODULES=geom_label geom_mirror
#
.if !defined(WITHOUT_RESCUE)
COMPRESS?=	bzip2
.else
COMPRESS=	uzip
BOOTMODULES+=	geom_uzip zlib
.endif

.if !defined(TARGET_ARCH)
TARGET_ARCH!=	${SYSCTL} -n hw.machine_arch
.endif

.if !defined(RELEASE)
RELEASE!=${UNAME} -r
.endif

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

all: image

extract: ${WRKDIR}/.extract_done
${WRKDIR}/.extract_done:
	@${MKDIR} ${WRKDIR}/mfs && ${CHOWN} root:wheel ${WRKDIR}/mfs
.if !defined(CUSTOM)
	@if [ ! -d "${BASE}" ]; then \
		echo "Please set the environment variable BASE to a path"; \
		echo "with FreeBSD distribution files (e.g. /cdrom/8.1-RELEASE)"; \
		echo "Or execute like: make BASE=/cdrom/8.1-RELEASE"; \
		exit 1; \
	fi
	@for DIR in base kernels; do \
		if [ ! -d "${BASE}/$$DIR" ]; then \
			echo "Cannot find directory \"${BASE}/$$DIR\""; \
			exit 1; \
		fi \
	done
	@echo -n "Extracting base and kernel ..."
	@${CAT} ${BASE}/base/base.?? | ${TAR} --unlink -xpzf - -C ${WRKDIR}/mfs
	@${CAT} ${BASE}/kernels/generic.?? | ${TAR} --unlink -xpzf - -C ${WRKDIR}/mfs/boot
	@${MV} ${WRKDIR}/mfs/boot/GENERIC/* ${WRKDIR}/mfs/boot/kernel
	@${RMDIR} ${WRKDIR}/mfs/boot/GENERIC
	@echo " done"
.endif
	@${TOUCH} ${WRKDIR}/.extract_done

build: extract ${WRKDIR}/.build_done
${WRKDIR}/.build_done:
.if defined(CUSTOM)
.if defined(BUILDWORLD)
	@echo -n "Building world ..."
	@cd ${SRC_DIR} && make buildworld TARGET_ARCH=${TARGET_ARCH}
.endif
.if defined(BUILDKERNEL)
	@echo -n "Building kernel KERNCONF=${KERNCONF} ..."
	@cd ${SRC_DIR} && make buildkernel KERNCONF=${KERNCONF} TARGET_ARCH=${TARGET_ARCH}
.endif
.endif
	@${TOUCH} ${WRKDIR}/.build_done

install: build ${WRKDIR}/.install_done
${WRKDIR}/.install_done:
.if defined(CUSTOM)
	@echo -n "Installing world and kernel KERNCONF=${KERNCONF} ..."
	@cd ${SRC_DIR} && make installworld DESTDIR="${WRKDIR}/mfs" TARGET_ARCH=${TARGET_ARCH}
	@cd ${SRC_DIR} && make distribution DESTDIR="${WRKDIR}/mfs" TARGET_ARCH=${TARGET_ARCH}
	@cd ${SRC_DIR} && make installkernel DESTDIR="${WRKDIR}/mfs" TARGET_ARCH=${TARGET_ARCH}
.endif
.if defined(SE)
	@echo -n "Creating FreeBSD distribution image ..."
	@mkdir -p ${WRKDIR}/dist
	@cd ${WRKDIR}/mfs && ${FIND} . -depth 1 \
		-exec ${TAR} -r -f ${WRKDIR}/dist/${RELEASE}-${TARGET_ARCH}.tar {} \; 
	@echo " done"
. if defined(COMPRESS)
	@echo "Compressing FreeBSD distribution image ..."
	@${COMPRESS_CMD} -v ${WRKDIR}/dist/${RELEASE}-${TARGET_ARCH}.tar
. endif
.endif
	@${CHFLAGS} -R noschg ${WRKDIR}/mfs > /dev/null 2> /dev/null || exit 0
.if !defined(WITHOUT_RESCUE)
	@cd ${WRKDIR}/mfs && \
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
	@cd ${WRKDIR}/mfs && ${RM} -rf rescue
.endif
	@${TOUCH} ${WRKDIR}/.install_done

prune: install ${WRKDIR}/.prune_done
${WRKDIR}/.prune_done:
	@echo -n "Removing selected files from distribution ..."
	@if [ -f "${PRUNELIST}" ]; then \
		for FILE in `cat ${PRUNELIST}`; do \
			if [ -n "$${FILE}" ]; then \
				${RM} -rf ${WRKDIR}/mfs/$${FILE}; \
			fi; \
		done; \
	fi
	@${TOUCH} ${WRKDIR}/.prune_done
	@echo " done"

packages: install prune ${WRKDIR}/.packages_done
${WRKDIR}/.packages_done:
	@if [ -d "${PACKAGESDIR}" ]; then \
		echo -n "Copying user packages ..."; \
		${CP} -rf ${PACKAGESDIR} ${WRKDIR}/mfs/packages; \
		${TOUCH} ${WRKDIR}/.packages_done; \
		echo " done"; \
	fi

config: install ${WRKDIR}/.config_done
${WRKDIR}/.config_done:
	@echo -n "Installing configuration scripts and files ..."
.for FILE in loader.conf rc.conf resolv.conf interfaces.conf
. if !exists(${CFGDIR}/${FILE}) && !exists(${CFGDIR}/${FILE}.sample)
	@echo "Missing ${CFGDIR}/$${FILE}.sample" && exit 1
. endif
.endfor
.if defined(SE)
	@${INSTALL} -m 0644 ${TOOLSDIR}/motd.se ${WRKDIR}/mfs/etc/motd
	@${INSTALL} -d -m 0755 ${WRKDIR}/mfs/cdrom
.else
	@${INSTALL} -m 0644 ${TOOLSDIR}/motd ${WRKDIR}/mfs/etc/motd
.endif
	@${MKDIR} ${WRKDIR}/mfs/stand ${WRKDIR}/mfs/etc/rc.conf.d
	@if [ -f "${CFGDIR}/loader.conf" ]; then \
		${INSTALL} -m 0644 ${CFGDIR}/loader.conf ${WRKDIR}/mfs/boot/loader.conf; \
	else \
		${INSTALL} -m 0644 ${CFGDIR}/loader.conf.sample ${WRKDIR}/mfs/boot/loader.conf; \
	fi
	@if [ -f "${CFGDIR}/rc.conf" ]; then \
		${INSTALL} -m 0644 ${CFGDIR}/rc.conf ${WRKDIR}/mfs/etc/rc.conf; \
	else \
		${INSTALL} -m 0644 ${CFGDIR}/rc.conf.sample ${WRKDIR}/mfs/etc/rc.conf; \
	fi
	@if [ -f "${CFGDIR}/resolv.conf" ]; then \
		${INSTALL} -m 0644 ${CFGDIR}/resolv.conf ${WRKDIR}/mfs/etc/resolv.conf; \
	fi
	@if [ -f "${CFGDIR}/interfaces.conf" ]; then \
		${INSTALL} -m 0644 ${CFGDIR}/interfaces.conf ${WRKDIR}/mfs/etc/rc.conf.d/interfaces; \
	fi
	@if [ -f "${CFGDIR}/authorized_keys" ]; then \
		${INSTALL} -d -m 0700 ${WRKDIR}/mfs/root/.ssh; \
		${INSTALL} ${CFGDIR}/authorized_keys ${WRKDIR}/mfs/root/.ssh/; \
	fi
	@${MKDIR} ${WRKDIR}/mfs/root/bin
	@${INSTALL} ${TOOLSDIR}/zfsinstall ${WRKDIR}/mfs/root/bin
	@${INSTALL} ${TOOLSDIR}/destroygeom ${WRKDIR}/mfs/root/bin
	@for SCRIPT in ${SCRIPTS}; do \
		${INSTALL} -m 0555 ${SCRIPTSDIR}/$${SCRIPT} ${WRKDIR}/mfs/etc/rc.d/; \
	done
	@${SED} -I -E 's/\(ttyv[2-7].*\)on /\1off/g' ${WRKDIR}/mfs/etc/ttys
	@echo "/dev/md0 / ufs rw 0 0" > ${WRKDIR}/mfs/etc/fstab
	@echo "md /tmp mfs rw,-s128m 0 0" >> ${WRKDIR}/mfs/etc/fstab
	@echo ${ROOTPW} | ${PW} -V ${WRKDIR}/mfs/etc usermod root -h 0
	@echo PermitRootLogin yes >> ${WRKDIR}/mfs/etc/ssh/sshd_config
	@echo 127.0.0.1 localhost > ${WRKDIR}/mfs/etc/hosts
	@${TOUCH} ${WRKDIR}/.config_done
	@echo " done"

genkeys: config ${WRKDIR}/.genkeys_done
${WRKDIR}/.genkeys_done:
	@echo -n "Generating SSH host keys ..."
	@${SSHKEYGEN} -t rsa1 -b 1024 -f ${WRKDIR}/mfs/etc/ssh/ssh_host_key -N '' > /dev/null
	@${SSHKEYGEN} -t dsa -f ${WRKDIR}/mfs/etc/ssh/ssh_host_dsa_key -N '' > /dev/null
	@${SSHKEYGEN} -t rsa -f ${WRKDIR}/mfs/etc/ssh/ssh_host_rsa_key -N '' > /dev/null
	@${TOUCH} ${WRKDIR}/.genkeys_done
	@echo " done"

compress-usr: install prune ${WRKDIR}/.compress-usr_done
${WRKDIR}/.compress-usr_done:
	@echo -n "Compressing usr ..."
. if defined(COMPRESS)
	@${TAR} -c -C ${WRKDIR}/mfs -f - usr | \
	${COMPRESS_CMD} -v -c > ${WRKDIR}/mfs/.usr.tar${SUFX} && \
	${RM} -rf ${WRKDIR}/mfs/usr && \
	${MKDIR} ${WRKDIR}/mfs/usr
.else
	@${MKDIR} ${WRKDIR}/mnt
	@${MAKEFS} -t ffs ${WRKDIR}/usr.img ${WRKDIR}/mfs/usr > /dev/null && \
	${MKUZIP} -o ${WRKDIR}/mfs/.usr.uzip ${WRKDIR}/usr.img > /dev/null && \
	${RM} -rf ${WRKDIR}/mfs/usr ${WRKDIR}/usr.img && ${MKDIR} ${WRKDIR}/mfs/usr
.endif
	@${TOUCH} ${WRKDIR}/.compress-usr_done
	@echo " done"

boot: install prune ${WRKDIR}/.boot_done
${WRKDIR}/.boot_done:
	@echo -n "Configuring boot environment ..."
	@${MKDIR} ${WRKDIR}/disk && ${CHOWN} root:wheel ${WRKDIR}/disk
	@${RM} -f ${WRKDIR}/mfs/boot/kernel/kernel.debug
	@${CP} -rp ${WRKDIR}/mfs/boot ${WRKDIR}/disk
	@${RM} -rf ${WRKDIR}/disk/boot/kernel/*.ko ${WRKDIR}/disk/boot/kernel/*.symbols
.if defined(DEBUG)
	@test -f ${WRKDIR}/mfs/boot/kernel/kernel.symbols \
	&& ${INSTALL} -m 0555 ${WRKDIR}/mfs/boot/kernel/kernel.symbols ${WRKDIR}/disk/boot/kernel >/dev/null 2>/dev/null || exit 0
.endif
.for FILE in ${BOOTMODULES}
	@test -f ${WRKDIR}/mfs/boot/kernel/${FILE}.ko \
	&& ${INSTALL} -m 0555 ${WRKDIR}/mfs/boot/kernel/${FILE}.ko ${WRKDIR}/disk/boot/kernel >/dev/null 2>/dev/null || exit 0
. if defined(DEBUG)
	@test -f ${WRKDIR}/mfs/boot/kernel/${FILE}.ko \
	&& ${INSTALL} -m 0555 ${WRKDIR}/mfs/boot/kernel/${FILE}.ko.symbols ${WRKDIR}/disk/boot/kernel >/dev/null 2>/dev/null || exit 0
. endif
.endfor
	@${MKDIR} -p ${WRKDIR}/disk/boot/modules
.for FILE in ${MFSMODULES}
	@test -f ${WRKDIR}/mfs/boot/kernel/${FILE}.ko \
	&& ${INSTALL} -m 0555 ${WRKDIR}/mfs/boot/kernel/${FILE}.ko ${WRKDIR}/mfs/boot/modules >/dev/null 2>/dev/null || exit 0
. if defined(DEBUG)
	@test -f ${WRKDIR}/mfs/boot/kernel/${FILE}.ko.symbols \
	&& ${INSTALL} -m 0555 ${WRKDIR}/mfs/boot/kernel/${FILE}.ko.symbols ${WRKDIR}/mfs/boot/modules >/dev/null 2>/dev/null || exit 0
. endif
.endfor
	@${RM} -rf ${WRKDIR}/mfs/boot/kernel
	@${TOUCH} ${WRKDIR}/.boot_done
	@echo " done"

mfsroot: install prune config genkeys boot compress-usr packages ${WRKDIR}/.mfsroot_done
${WRKDIR}/.mfsroot_done:
	@echo -n "Creating and compressing mfsroot ..."
	@${MKDIR} ${WRKDIR}/mnt
	@${MAKEFS} -t ffs -m ${MFSROOT_MAXSIZE} -f ${MFSROOT_FREE_INODES} -b ${MFSROOT_FREE_BLOCKS} ${WRKDIR}/disk/mfsroot ${WRKDIR}/mfs > /dev/null
	@${RM} -rf ${WRKDIR}/mnt ${WRKDIR}/mfs
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
	@${CP} ${WRKDIR}/dist/${RELEASE}-${TARGET_ARCH}.tar${SUFX} ${WRKDIR}/disk/
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
	@if [ ! -x "${MKISOFS}" ]; then exit 1; fi
	@echo -n "Creating ISO image ..."
	@${MKISOFS} -b boot/cdboot -no-emul-boot -r -J -V mfsBSD -o ${ISOIMAGE} ${WRKDIR}/disk > /dev/null 2> /dev/null
	@echo " done"
	@${LS} -l ${ISOIMAGE}

tar: install prune config boot compress-usr mfsroot fbsddist ${TARFILE}
${TARFILE}:
	@echo -n "Creating tar file ..."
	@cd ${WRKDIR}/disk && ${FIND} . -depth 1 \
		-exec ${TAR} -r -f ${CURDIR}/${TARFILE} {} \;
	@echo " done"
	@${LS} -l ${TARFILE}

clean:
	@if [ -d ${WRKDIR} ]; then ${CHFLAGS} -R noschg ${WRKDIR}; fi
	@cd ${WRKDIR} && ${RM} -rf mfs mnt disk dist trees .*_done
