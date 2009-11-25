# $Id$
#
# mfsBSD
# Copyright (c) 2007-2008 Martin Matuska <mm at FreeBSD.org>
#
# Version 1.0-BETA4
#

#
# User-defined variables
#
BASE?=/cdrom/8.0-RELEASE
IMAGE?=	mfsboot.img
ISOIMAGE?= mfsboot.iso
TARFILE?= mfsboot.tar.gz
KERNCONF?= GENERIC
MFSROOT_FREE_INODES?=5%
MFSROOT_FREE_BLOCKS?=5%
MFSROOT_MAXSIZE?=45m
ROOTPW?= mfsbsd

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
SRCDIR?=/usr/src
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
PW=/usr/sbin/pw
SED=/usr/bin/sed
UNAME=/usr/bin/uname
BZIP2=/usr/bin/bzip2
MAKEFS=/usr/sbin/makefs
SSHKEYGEN=/usr/bin/ssh-keygen
MKISOFS=/usr/local/bin/mkisofs
#
CURDIR!=${PWD}
WRKDIR?=${CURDIR}/tmp
#
BSDLABEL=bsdlabel
#
STEPS=7
#
DOFS=${TOOLSDIR}/doFS.sh
SCRIPTS=mdinit mfsbsd interfaces packages
BOOTMODULES=acpi snp geom_uzip zlib opensolaris zfs
MFSMODULES=geom_label geom_mirror
#

all: image

extract: ${WRKDIR}/.extract_done
${WRKDIR}/.extract_done:
	@${MKDIR} ${WRKDIR}/mfs && ${CHOWN} root:wheel ${WRKDIR}/mfs
.if !defined(CUSTOM)
	@if [ ! -d "${BASE}" ]; then \
		echo "Please set the environment variable BASE to a path"; \
		echo "with FreeBSD distribution files (e.g. /cdrom/7.2-RELEASE)"; \
		echo "Or execute like: make BASE=/cdrom/7.2-RELEASE"; \
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
	@${RM} -rf ${WRKDIR}/mfs/boot/kernel/*.symbols
	@${CHFLAGS} -R noschg ${WRKDIR}/mfs > /dev/null 2> /dev/null || exit 0
	@echo " done"
.endif
	@${TOUCH} ${WRKDIR}/.extract_done

build: extract ${WRKDIR}/.build_done
${WRKDIR}/.build_done:
.if defined(CUSTOM)
.if defined(BUILDWORLD)
	@echo -n "Building world ..."
	@cd ${SRCDIR} && make buildworld
.endif
.if defined(BUILDKERNEL)
	@echo -n "Building kernel KERNCONF=${KERNCONF} ..."
	@cd ${SRCDIR} && make buildkernel KERNCONF=${KERNCONF}
.endif
.endif
	@${TOUCH} ${WRKDIR}/.build_done

install: build ${WRKDIR}/.install_done
${WRKDIR}/.install_done:
.if defined(CUSTOM)
	@echo -n "Installing world and kernel KERNCONF=${KERNCONF} ..."
	@cd ${SRCDIR} && make installworld DESTDIR="${WRKDIR}/mfs"
	@cd ${SRCDIR} && make distribution DESTDIR="${WRKDIR}/mfs"
	@cd ${SRCDIR} && make installkernel DESTDIR="${WRKDIR}/mfs"
	@${RM} -rf ${WRKDIR}/mfs/boot/kernel/*.symbols
	@${CHFLAGS} -R noschg ${WRKDIR}/mfs > /dev/null 2> /dev/null || exit 0
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
	@for FILE in loader.conf rc.conf resolv.conf interfaces.conf; do \
		if [ ! -f "${CFGDIR}/$${FILE}" ]; then \
			if [ ! -f "${CFGDIR}/$${FILE}.sample" ]; then \
				echo "Missing ${CFGDIR}/$${FILE}.sample"; \
				exit 1; \
			fi \
		fi \
	done
	@${RM} -f ${WRKDIR}/mfs/etc/motd
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
		${INSTALL} -m 0700 ${WRKDIR}/mfs/root/.ssh; \
		${INSTALL} ${CFGDIR}/authorized_keys ${WRKDIR}/mfs/root/.ssh/ \
	fi
	@${MKDIR} ${WRKDIR}/mfs/root/bin
	@${INSTALL} ${TOOLSDIR}/zfsinstall ${WRKDIR}/mfs/root/bin
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

usr.uzip: install prune ${WRKDIR}/.usr.uzip_done
${WRKDIR}/.usr.uzip_done:
	@echo -n "Creating usr.uzip ..."
	@${MKDIR} ${WRKDIR}/mnt
	@${MAKEFS} -t ffs ${WRKDIR}/usr.img ${WRKDIR}/mfs/usr > /dev/null
	@${MKUZIP} -o ${WRKDIR}/mfs/usr.uzip ${WRKDIR}/usr.img > /dev/null
	@${RM} -rf ${WRKDIR}/mfs/usr ${WRKDIR}/usr.img && ${MKDIR} ${WRKDIR}/mfs/usr
	@${TOUCH} ${WRKDIR}/.usr.uzip_done
	@echo " done"

boot: install prune ${WRKDIR}/.boot_done
${WRKDIR}/.boot_done:
	@echo -n "Configuring boot environment ..."
	@${MKDIR} ${WRKDIR}/disk && ${CHOWN} root:wheel ${WRKDIR}/disk
	@${RM} -f ${WRKDIR}/mfs/boot/kernel/kernel.debug
	@${CP} -rp ${WRKDIR}/mfs/boot ${WRKDIR}/disk
	@${RM} -rf ${WRKDIR}/disk/boot/kernel/*.ko
	@for FILE in ${BOOTMODULES}; do \
		test -f ${WRKDIR}/mfs/boot/kernel/$${FILE}.ko && ${INSTALL} -m 0555 ${WRKDIR}/mfs/boot/kernel/$${FILE}.ko ${WRKDIR}/disk/boot/kernel >/dev/null 2>/dev/null; \
	done
	@${MKDIR} -p ${WRKDIR}/disk/boot/modules
	@for FILE in ${MFSMODULES}; do \
		test -f ${WRKDIR}/mfs/boot/kernel/$${FILE}.ko && ${INSTALL} -m 0555 ${WRKDIR}/mfs/boot/kernel/$${FILE}.ko ${WRKDIR}/mfs/boot/modules >/dev/null 2>/dev/null; \
	done
	@${RM} -rf ${WRKDIR}/mfs/boot/kernel
	@${TOUCH} ${WRKDIR}/.boot_done
	@echo " done"

mfsroot: install prune config genkeys boot usr.uzip packages ${WRKDIR}/.mfsroot_done
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

image: install prune config genkeys boot usr.uzip mfsroot ${IMAGE}
${IMAGE}:
	@echo -n "Creating image file ..."
	@${MKDIR} ${WRKDIR}/mnt ${WRKDIR}/trees/base/boot
	@${INSTALL} -m 0444 ${WRKDIR}/disk/boot/boot ${WRKDIR}/trees/base/boot/
#	@${MAKEFS} -t ffs ${WRKDIR}/disk.img ${WRKDIR}/disk
	@${DOFS} ${BSDLABEL} "" ${WRKDIR}/disk.img ${WRKDIR} ${WRKDIR}/mnt 0 ${WRKDIR}/disk 80000 auto > /dev/null 2> /dev/null
	@${RM} -rf ${WRKDIR}/mnt ${WRKDIR}/trees
	@${MV} ${WRKDIR}/disk.img ${IMAGE}
	@echo " done"
	@${LS} -l ${IMAGE}

iso: install prune config genkeys boot usr.uzip mfsroot ${ISOIMAGE}
${ISOIMAGE}:
	@if [ ! -x "${MKISOFS}" ]; then exit 1; fi
	@echo -n "Creating ISO image ..."
	@${MKISOFS} -b boot/cdboot -no-emul-boot -r -J -V mfsBSD -o ${ISOIMAGE} ${WRKDIR}/disk > /dev/null 2> /dev/null
	@echo " done"
	@${LS} -l ${ISOIMAGE}

tar: install prune config boot usr.uzip mfsroot ${TARFILE}
${TARFILE}:
	@echo -n "Creating tar.gz file ..."
	@${TAR} -c -z -f ${TARFILE} -C ${WRKDIR}/disk boot mfsroot.gz
	@echo " done"
	@${LS} -l ${TARFILE}

clean:
	@if [ -d ${WRKDIR} ]; then ${CHFLAGS} -R noschg ${WRKDIR}; fi
	@cd ${WRKDIR} && ${RM} -rf mfs mnt disk trees .*_done
