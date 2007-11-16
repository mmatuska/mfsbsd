# mfsBSD
# Copyright (c) 2007 Martin Matuska <mm at FreeBSD.org>
#
# $Id$

#
# User-defined variables
#
BASE?=/cdrom/7.0-BETA2
IMAGE?=	disk.img
ISOIMAGE?= disk.iso

#
# Paths
#
WRKDIR?=tmp
CFGDIR=conf
SCRIPTSDIR=scripts
PACKAGESDIR=packages
FILESDIR=files
TOOLSDIR=tools
#
# Program defaults
#
MKDIR=/bin/mkdir -p
CHOWN=/usr/sbin/chown
CAT=/bin/cat
TAR=/usr/bin/tar
CP=/bin/cp
MV=/bin/mv
RM=/bin/rm
CHFLAGS=/bin/chflags
CHMOD=/bin/chmod
MKUZIP=/usr/bin/mkuzip
GZIP=/usr/bin/gzip
TOUCH=/usr/bin/touch
LS=/bin/ls
UNAME=/usr/bin/uname
MKISOFS=/usr/local/bin/mkisofs
#
BSDLABEL=bsdlabel
#
STEPS=7
#
CURDIR!=pwd
#
DOFS=${TOOLSDIR}/doFS.sh
SCRIPTS=mdinit rootpw interfaces packages
BOOTMODULES=acpi snp geom_uzip zlib
MFSMODULES=geom_label geom_mirror

all: image

extract: ${WRKDIR}/.extract_done
${WRKDIR}/.extract_done:
	@if [ ! -d "${BASE}" ]; then \
		echo "Please set the environment variable DIST to a path"; \
		echo "with FreeBSD distribution files(e.g. /cdrom/7.0-RELEASE)"; \
		echo "Or execute like: make DIST=/cdrom/7.0-RELEASE"; \
		exit 1; \
	fi
	@for DIR in base kernels; do \
		if [ ! -d "${BASE}/$$DIR" ]; then \
			echo "Cannot find directory \"${BASE}/$$DIR\""; \
			exit 1; \
		fi \
	done
	@echo -n "Extracting base and kernel ..."
	@${MKDIR} ${WRKDIR}/mfs && ${CHOWN} root:wheel ${WRKDIR}/mfs
	@${CAT} ${BASE}/base/base.?? | ${TAR} --unlink -xpzf - -C ${WRKDIR}/mfs
	@${CAT} ${BASE}/kernels/generic.?? | ${TAR} --unlink -xpzf - -C ${WRKDIR}/mfs/boot
	@${MV} ${WRKDIR}/mfs/boot/GENERIC/* ${WRKDIR}/mfs/boot/kernel
	@${RM} -rf ${WRKDIR}/mfs/boot/kernel/*.symbols
	@${CHFLAGS} -R noschg ${WRKDIR}/mfs > /dev/null 2> /dev/null || exit 0
	@${TOUCH} ${WRKDIR}/.extract_done
	@echo " done"

prune: extract ${WRKDIR}/.prune_done
${WRKDIR}/.prune_done:
	@echo -n "Removing unnecessary files from distribution ..."
	@${RM} -rf ${WRKDIR}/mfs/rescue ${WRKDIR}/mfs/usr/include
	@${RM} -f ${WRKDIR}/mfs/usr/lib/*.a
	@${RM} -f ${WRKDIR}/mfs/usr/libexec/cc1* ${WRKDIR}/mfs/usr/libexec/f771
	@for x in c++ g++ CC gcc cc yacc byacc f77 addr2line	\
		ar as gasp gdb gdbreplay ld nm objcopy objdump	\
		ranlib readelf size strip; do \
		${RM} -f ${WRKDIR}/mfs/usr/bin/$$x; \
	done
	@${TOUCH} ${WRKDIR}/.prune_done
	@echo " done"

packages: extract prune ${WRKDIR}/.packages_done
${WRKDIR}/.packages_done:
	@if [ -d "${PACKAGESDIR}" ]; then \
		echo -n "Copying user packages ..."; \
		${CP} -rf ${PACKAGESDIR} ${WRKDIR}/mfs/packages; \
		${TOUCH} ${WRKDIR}/.packages_done; \
		echo " done"; \
	fi

config: extract ${WRKDIR}/.config_done
${WRKDIR}/.config_done:
	@echo -n "Installing configuration scripts and files ..."
	@for FILE in loader.conf rc.conf resolv.conf interfaces.conf rootpw.conf; do \
		if [ ! -f "${CFGDIR}/$${FILE}" ]; then \
			if [ ! -f "${CFGDIR}/$${FILE}.sample" ]; then \
				echo "Missing ${CFGDIR}/$${FILE}.sample"; \
				exit 1; \
			else \
			${CP} ${CFGDIR}/$${FILE}.sample ${CFGDIR}/$${FILE}; \
			fi \
		fi \
	done
	@${RM} -f ${WRKDIR}/mfs/etc/motd
	@${MKDIR} ${WRKDIR}/mfs/stand ${WRKDIR}/mfs/etc/rc.conf.d
	@${CP} ${CFGDIR}/loader.conf ${WRKDIR}/mfs/boot/
	@${CP} ${CFGDIR}/rc.conf ${CFGDIR}/resolv.conf ${WRKDIR}/mfs/etc/
	@${CP} ${CFGDIR}/interfaces.conf ${WRKDIR}/mfs/etc/rc.conf.d/interfaces
	@${CP} ${CFGDIR}/rootpw.conf ${WRKDIR}/mfs/etc/rc.conf.d/rootpw
	@for SCRIPT in ${SCRIPTS}; do \
		${CP} ${SCRIPTSDIR}/$${SCRIPT} ${WRKDIR}/mfs/etc/rc.d/; \
		${CHMOD} 555 ${WRKDIR}/mfs/etc/rc.d/$${SCRIPT}; \
	done
	@echo "/dev/md0 / ufs rw 0 0" > ${WRKDIR}/mfs/etc/fstab
	@echo PermitRootLogin yes >> ${WRKDIR}/mfs/etc/ssh/sshd_config
	@echo 127.0.0.1 localhost > ${WRKDIR}/mfs/etc/hosts
	@${TOUCH} ${WRKDIR}/.config_done
	@echo " done"

usr.uzip: extract prune ${WRKDIR}/.usr.uzip_done
${WRKDIR}/.usr.uzip_done:
	@echo -n "Creating usr.uzip ..."
	@${MKDIR} ${WRKDIR}/mnt
	@${DOFS} "" "" ${WRKDIR}/usr.img "" ${WRKDIR}/mnt 0 ${WRKDIR}/mfs/usr 8000 auto > /dev/null 2> /dev/null
	@${MKUZIP} -o ${WRKDIR}/mfs/usr.uzip ${WRKDIR}/usr.img > /dev/null
	@${RM} -rf ${WRKDIR}/mfs/usr ${WRKDIR}/usr.img && ${MKDIR} ${WRKDIR}/mfs/usr
	@${TOUCH} ${WRKDIR}/.usr.uzip_done
	@echo " done"

boot: extract prune ${WRKDIR}/.boot_done
${WRKDIR}/.boot_done:
	@echo -n "Configuring boot environment ..."
	@${MKDIR} ${WRKDIR}/disk && ${CHOWN} root:wheel ${WRKDIR}/disk
	@${RM} -f ${WRKDIR}/mfs/boot/kernel/kernel.debug
	@${CP} -rp ${WRKDIR}/mfs/boot ${WRKDIR}/disk
	@${RM} -rf ${WRKDIR}/disk/boot/kernel/*.ko
	@for FILE in ${BOOTMODULES}; do \
		test -f ${WRKDIR}/mfs/boot/kernel/$${FILE}.ko && ${CP} -f ${WRKDIR}/mfs/boot/kernel/$${FILE}.ko ${WRKDIR}/disk/boot/kernel/$${FILE}.ko >/dev/null 2>/dev/null; \
	done
	@${MKDIR} -p ${WRKDIR}/disk/boot/modules
	@for FILE in ${MFSMODULES}; do \
		test -f ${WRKDIR}/mfs/boot/kernel/$${FILE}.ko && ${MV} -f ${WRKDIR}/mfs/boot/kernel/$${FILE}.ko ${WRKDIR}/mfs/boot/modules/ >/dev/null 2>/dev/null; \
	done
	@${RM} -rf ${WRKDIR}/mfs/boot/kernel
	@${TOUCH} ${WRKDIR}/.boot_done
	@echo " done"

mfsroot: extract prune config boot usr.uzip packages ${WRKDIR}/.mfsroot_done
${WRKDIR}/.mfsroot_done:
	@echo -n "Creating and compressing mfsroot ..."
	@${MKDIR} ${WRKDIR}/mnt
	@${DOFS} "" "" ${WRKDIR}/disk/mfsroot "" ${WRKDIR}/mnt 0 ${WRKDIR}/mfs 8000 auto > /dev/null 2> /dev/null
	@${RM} -rf ${WRKDIR}/mnt ${WRKDIR}/mfs
	@${GZIP} -9 -f ${WRKDIR}/disk/mfsroot
	@${GZIP} -9 -f ${WRKDIR}/disk/boot/kernel/kernel
	@${CP} ${CFGDIR}/loader.conf ${WRKDIR}/disk/boot/
	@${TOUCH} ${WRKDIR}/.mfsroot_done
	@echo " done"

image: extract prune config boot usr.uzip mfsroot ${WRKDIR}/.image_done
${WRKDIR}/.image_done:
	@echo -n "Creating image file ..."
	@${MKDIR} ${WRKDIR}/mnt ${WRKDIR}/trees/base/boot
	@${CP} ${WRKDIR}/disk/boot/boot ${WRKDIR}/trees/base/boot/
	@${DOFS} ${BSDLABEL} "" ${WRKDIR}/disk.img ${WRKDIR} ${WRKDIR}/mnt 0 ${WRKDIR}/disk 80000 auto > /dev/null 2> /dev/null
	@${RM} -rf ${WRKDIR}/mnt ${WRKDIR}/trees
	@${MV} ${WRKDIR}/disk.img ${IMAGE}
	@${TOUCH} ${WRKDIR}/.image_done
	@echo " done"

iso: extract prune config boot usr.uzip mfsroot ${WRKDIR}/.iso_done
${WRKDIR}/.iso_done:
	@if [ -x "${MKISOFS}" ]; then exit 1; fi
	@echo -n "Creating ISO image ..."
	@${MKISOFS} -b boot/cdboot -no-emul-boot -r -J -V mfsBSD -o ${ISOIMAGE} ${WRKDIR}/disk
	@${TOUCH} ${WRKDIR}/.iso_done
	@echo " done"

clean:
	@if [ -d ${WRKDIR} ]; then ${CHFLAGS} -R noschg ${WRKDIR}; fi
	@${RM} -rf ${WRKDIR}
